`timescale 1ns / 1ns

// SDRAM 控制器（单请求口）
//
// 仲裁已经上移到 device：这里只服务"一个"已锁存的请求，做完就等下一个。
// 请求方（device）保证：request_valid 是单拍脉冲，且 request_busy=0 时才发；
// 本模块把请求锁进 pending_*，整个事务期间 request_busy 保持 1。
//
// 接口和 boot_rom 一致：valid/we/be/addr/data 进，request_busy 高到事务结束，
// 读的 8 拍走 respond_valid/respond_data。
// "事务结束" = request_busy 落回 0（写没有响应，不能靠 respond_valid 判断）。
module sdram_ctr (
    input clk,
    input rst_n,

    // 请求（单口）
    input          request_valid,
    input          request_we,
    // 21 地址 + 3 偏置
    input  [15:0]  request_be,
    input  [23:0]  request_addr,
    input  [127:0] request_data,
    output         request_busy,
    output reg     respond_valid,
    output         [15:0] respond_data,

    // SDRAM 通信
    output reg        sdram_cke,
    output reg        sdram_cs_n,
    output reg        sdram_ras_n,
    output reg        sdram_cas_n,
    output reg        sdram_we_n,
    output reg [1:0]  sdram_ba,
    output     [1:0]  sdram_dm,
    output reg [12:0] sdram_a,
    // DQ 拆成三路，方便外面接 PIC 版 PHY（输出寄存器 + 输入寄存器 + 三态）
    output     [15:0] sdram_dq_out,
    output            sdram_dq_oe,      // 1 = 驱动 DQ
    input      [15:0] sdram_dq_in       // 读回的数据（已由 PHY 寄存）
);

// 指令编码
// 用法：{sdram_ras_n, sdram_cas_n, sdram_we_n} <= X
localparam NOP = 3'h7;
localparam ACTIVE = 3'h3;
localparam READ = 3'h5;
localparam WRITE = 3'h4;
localparam PRECHARGE = 3'h2;
localparam AUTO_REFRESH = 3'h1;
localparam LOAD_MODE_REGISTER = 3'h0;

// 延迟（50 MHz / 20 ns 一拍；按 IS42S16160B 的最小时序取整）
localparam tRP  = 13'h2;
localparam tRFC = 13'h4;    // tRFC ~70 ns -> 4 拍
localparam tMRD = 13'h2;    // tMRD 2 tCK  -> 2 拍
localparam tNOP = 13'h0;
localparam tCL  = 13'h2;    // 读数据窗口起点：PHY 让命令/数据各晚 1 拍，实测 2 拍刚好（仿真模型偏 1 拍）
localparam tRCD = 13'h2;
localparam tRW  = 13'h7;    // BL=8 写突发的数据拍数
localparam rRTP = 13'h1;    // 读后到 PRECHARGE
localparam rWR  = 13'h1;    // tWR ~15 ns -> 1 拍

// 刷新周期（50MHz：385 x 20ns = 7.7us <= 7.8us）
localparam tFresh = 9'd385;   // 50MHz: 7.7us

// 状态编码
localparam INIT  = 3'h0;
localparam IDLE  = 3'h1;
localparam RUN   = 3'h2;
localparam FRESH = 3'h3;
reg [2:0] status;
reg [2:0] stage;

// 等待时间
reg [12:0] wait_time;

// 刷新倒计时，385 周期刷新一次
reg [8:0] refresh_time;

// 当前 4 个 bank 的激活行编码
reg        is_active  [3:0];
reg [12:0] active_row [3:0];

// 待处理请求（只有一个槽位）
reg         pending;
reg         pending_we;
reg [15:0]  pending_be;
reg [23:0]  pending_addr;
reg [127:0] pending_data;

// 开放 sdram_ctr 到 sdram 通道
reg sdramctr_to_sdram_pass;

// ---------------------------------组合逻辑---------------------------------
assign request_busy = pending;
assign sdram_dq_out = pending_data[{pending_addr[2:0] + ~wait_time[2:0], 4'h0} +: 16];
assign sdram_dq_oe = sdramctr_to_sdram_pass;
assign sdram_dm = !sdramctr_to_sdram_pass ? 2'h0 : {!pending_be[{pending_addr[2:0] + ~wait_time[2:0], 1'h1}], !pending_be[{pending_addr[2:0] + ~wait_time[2:0], 1'h0}]};
assign respond_data = respond_valid ? sdram_dq_in : 16'h0;
// ---------------------------------组合逻辑---------------------------------

task automatic precharge_all();
    wait_time <= tRP;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= PRECHARGE;
    sdram_a[10] <= 1'h1;
    is_active[0] <= 1'h0;
    is_active[1] <= 1'h0;
    is_active[2] <= 1'h0;
    is_active[3] <= 1'h0;
endtask

task automatic auto_refresh();
    wait_time <= tRFC;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= AUTO_REFRESH;
endtask

task automatic load_mode_register(input [9:0] mode);
    wait_time <= tMRD;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= LOAD_MODE_REGISTER;
    sdram_a <= {3'h0, mode};
endtask

task automatic nop(input [12:0] t);
    wait_time <= t;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= NOP;
endtask

task automatic active(input [1:0] ba, input [12:0] a);
    wait_time <= tRCD;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= ACTIVE;
    sdram_ba <= ba;
    sdram_a <= a;
    is_active[ba] <= 1'h1;
    active_row[ba] <= a;
endtask

task automatic precharge(input [1:0] ba);
    wait_time <= tRP;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= PRECHARGE;
    sdram_ba <= ba;
    sdram_a[10] <= 1'h0;
    is_active[ba] <= 1'h0;
endtask

task automatic read_begin(input [1:0] ba, input [8:0] a);
    wait_time <= tCL;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= READ;
    sdram_ba <= ba;
    sdram_a[8:0] <= a;
    sdram_a[10] <= 1'h0;
endtask

task automatic write_begin(input [1:0] ba, input [8:0] a);
    wait_time <= tRW;
    {sdram_ras_n, sdram_cas_n, sdram_we_n} <= WRITE;
    sdram_ba <= ba;
    sdram_a[8:0] <= a;
    sdram_a[10] <= 1'h0;
    sdramctr_to_sdram_pass <= 1'h1;
endtask

task automatic run_check(input cache_request_we, input [23:0] cache_request_addr);
    status <= RUN;
    if (is_active[cache_request_addr[4:3]]) begin
        // 激活的行就是需要的
        if (active_row[cache_request_addr[4:3]] == cache_request_addr[23:11]) begin
            if (!cache_request_we) begin
                stage <= 3'h2;
                read_begin(cache_request_addr[4:3], {cache_request_addr[10:5], cache_request_addr[2:0]});
            end
            else begin
                stage <= 3'h5;
                write_begin(cache_request_addr[4:3], {cache_request_addr[10:5], cache_request_addr[2:0]});
            end
        end
        // 激活的行不是需要的
        else begin
            stage <= 3'h0;
            precharge(cache_request_addr[4:3]);
        end
    end
    // 行未激活
    else begin
        stage <= 3'h1;
        active(cache_request_addr[4:3], cache_request_addr[23:11]);
    end
endtask

task automatic fresh_check();
    status <= FRESH;
    refresh_time <= tFresh;
    if (is_active[0] || is_active[1] || is_active[2] || is_active[3]) begin
        stage <= 3'h0;
        precharge_all();
    end
    else begin
        stage <= 3'h1;
        auto_refresh();
    end
endtask

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_valid <= 1'h0;
        sdram_cke <= 1'h0;
        sdram_cs_n <= 1'h1;
        status <= INIT;
        stage <= 3'h0;
        wait_time <= 13'h1fff;
        refresh_time <= 9'h0;
        pending <= 1'h1;
        sdramctr_to_sdram_pass <= 1'h0;
    end
    else begin
        // 更新刷新倒计时
        if (refresh_time != 9'h0) begin
            refresh_time <= refresh_time - 9'h1;
        end

        // 存储暂时无法处理的请求（单拍脉冲，来者不拒地锁进槽位）
        if (!pending && request_valid) begin
            pending <= 1'h1;
            pending_we <= request_we;
            pending_be <= request_be;
            pending_addr <= request_addr;
            pending_data <= request_data;
        end

        // 等待上一条指令完成
        if (wait_time != 13'h0) begin
            nop(wait_time - 13'h1);
        end
        // 状态，阶段切换
        // 每个阶段一定要置 wait_time
        else begin
            stage <= stage + 3'h1;
            case (status)
                INIT: begin
                    case (stage)
                        3'h0: begin
                            // 置 sdram_cke, sdram_cs_n
                            wait_time <= 13'h0;
                            sdram_cke <= 1'h1;
                            sdram_cs_n <= 1'h0;
                        end
                        3'h1: begin
                            precharge_all();
                        end
                        3'h2: begin
                            auto_refresh();
                        end
                        3'h3: begin
                            auto_refresh();
                        end
                        3'h4: begin
                            load_mode_register(10'b0000100011);
                        end
                        default: begin
                            // 置 refresh_time, 放开请求
                            status <= IDLE;
                            stage <= 3'h0;
                            refresh_time <= tFresh;
                            pending <= 1'h0;
                            nop(tNOP);
                        end
                    endcase
                end
                IDLE: begin
                    if (refresh_time == 9'h0) begin
                        fresh_check();
                    end
                    // 请求已经锁在寄存器里，直接解码
                    else if (pending) begin
                        run_check(pending_we, pending_addr);
                    end
                    else begin
                        stage <= 3'h0;
                        nop(tNOP);
                    end
                end
                RUN: begin
                    case (stage)
                        3'h0: begin
                            active(pending_addr[4:3], pending_addr[23:11]);
                        end
                        3'h1: begin
                            if (!pending_we) begin
                                read_begin(pending_addr[4:3], {pending_addr[10:5], pending_addr[2:0]});
                            end
                            else begin
                                stage <= 3'h5;
                                write_begin(pending_addr[4:3], {pending_addr[10:5], pending_addr[2:0]});
                            end
                        end
                        3'h2: begin
                            respond_valid <= 1'h1;
                            nop(tRW);
                        end
                        3'h3: begin
                            respond_valid <= 1'h0;
                            nop(rRTP);
                        end
                        3'h5: begin
                            sdramctr_to_sdram_pass <= 1'h0;
                            nop(rWR);
                        end
                        default: begin
                            pending <= 1'h0;
                            if (refresh_time == 9'h0) begin
                                fresh_check();
                            end
                            else begin
                                status <= IDLE;
                                stage <= 3'h0;
                                nop(tNOP);
                            end
                        end
                    endcase
                end
                FRESH: begin
                    case (stage)
                        3'h0: begin
                            auto_refresh();
                        end
                        default: begin
                            status <= IDLE;
                            stage <= 3'h0;
                            nop(tNOP);
                        end
                    endcase
                end
                default: ;
            endcase
        end
    end
end

endmodule
