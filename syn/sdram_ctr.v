`timescale 1ns / 1ns

module sdram_ctr (
    input              clk,
    input              rst_n,

    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [31:0]  request_addr,
    input      [127:0] request_data,
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data,

    // SDRAM 通信
    output             sdram_cke,
    output             sdram_cs_n,
    output             sdram_ras_n,
    output             sdram_cas_n,
    output             sdram_we_n,
    output     [1:0]   sdram_ba,
    output     [1:0]   sdram_dm,
    output     [12:0]  sdram_a,
    inout      [15:0]  sdram_dq
);

// #region I/O 区
reg         nxt_sdram_dq_oe;

reg         sdram_cke_set;
reg         sdram_cs_n_set;
reg         sdram_ras_n_set;
reg         sdram_cas_n_set;
reg         sdram_we_n_set;
reg         sdram_ba_set;
reg         sdram_dm_set;
reg         sdram_a_set;
reg         sdram_dq_out_set;

reg         nxt_sdram_cke;
reg         nxt_sdram_cs_n;
reg         nxt_sdram_ras_n;
reg         nxt_sdram_cas_n;
reg         nxt_sdram_we_n;
reg  [1:0]  nxt_sdram_ba;
reg  [1:0]  nxt_sdram_dm;
reg  [12:0] nxt_sdram_a;
reg  [15:0] nxt_sdram_dq_out;
wire [15:0] sdram_dq_in;
// 组合逻辑接口


reg        sdram_dq_oe;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sdram_dq_oe <= 1'h0;
    end
    else begin
        sdram_dq_oe <= nxt_sdram_dq_oe;
    end
end

generate
    OFS1P3DX u_cke (
        .CD(!rst_n),
        .D(nxt_sdram_cke),
        .SP(sdram_cke_set),
        .SCLK(clk),
        .Q(sdram_cke)
    );

    OFS1P3BX u_cs_n (
        .PD(!rst_n),
        .D(nxt_sdram_cs_n),
        .SP(sdram_cs_n_set),
        .SCLK(clk),
        .Q(sdram_cs_n)
    );

    OFS1P3BX u_ras_n (
        .PD(1'h0),
        .D(nxt_sdram_ras_n),
        .SP(sdram_ras_n_set),
        .SCLK(clk),
        .Q(sdram_ras_n)
    );

    OFS1P3BX u_cas_n (
        .PD(1'h0),
        .D(nxt_sdram_cas_n),
        .SP(sdram_cas_n_set),
        .SCLK(clk),
        .Q(sdram_cas_n)
    );

    OFS1P3BX u_we_n (
        .PD(1'h0),
        .D(nxt_sdram_we_n),
        .SP(sdram_we_n_set),
        .SCLK(clk),
        .Q(sdram_we_n)
    );

    genvar i;
    for (i = 0; i < 2; i = i + 1) begin : g_0
        OFS1P3DX u_ba (
            .CD(1'h0),
            .D(nxt_sdram_ba[i]),
            .SP(sdram_ba_set),
            .SCLK(clk),
            .Q(sdram_ba[i])
        );

        OFS1P3DX u_dm (
            .CD(1'h0),
            .D(nxt_sdram_dm[i]),
            .SP(sdram_dm_set),
            .SCLK(clk),
            .Q(sdram_dm[i])
        );
    end

    for (i = 0; i < 13; i = i + 1) begin : g_1
        OFS1P3DX u_a (
            .CD(1'h0),
            .D(nxt_sdram_a[i]),
            .SP(sdram_a_set),
            .SCLK(clk),
            .Q(sdram_a[i])
        );
    end

    for (i = 0; i < 16; i = i + 1) begin : g_2
        wire dq_in;
        wire dq_out;

        OFS1P3DX u_dq_out (
            .CD(1'h0),
            .D(nxt_sdram_dq_out[i]),
            .SP(1'h1),
            .SCLK(clk),
            .Q(dq_out)
        );

        IFS1P3DX u_dq_in (
            .CD(1'h0),
            .D(dq_in),
            .SP(1'h1),
            .SCLK(clk),
            .Q(sdram_dq_in[i])
        );

        BB u_dq_bb (
            .I(dq_out),
            .T(!sdram_dq_oe),
            .O(dq_in),
            .B(sdram_dq[i])
        );
    end
endgenerate
// #endregion

// 指令编码
// 用法：{sdram_ras_n, sdram_cas_n, sdram_we_n} <= X
localparam NOP                = 3'h7;
localparam ACTIVE             = 3'h3;
localparam READ               = 3'h5;
localparam WRITE              = 3'h4;
localparam PRECHARGE          = 3'h2;
localparam AUTO_REFRESH       = 3'h1;
localparam LOAD_MODE_REGISTER = 3'h0;

// 延迟（50 MHz / 20 ns 一拍；按 IS42S16160B 的最小时序取整）
localparam tRP  = 13'h2;    // precharge_all 延迟
localparam tRFC = 13'h4;    // auto_refresh 延迟
localparam tMRD = 13'h2;    // load_mode_register 延迟
localparam tCL  = 13'h1;    // 读数据窗口起点：PHY 让命令/数据各晚 1 拍，实测 2 拍刚好（仿真模型偏 1 拍）
localparam tRCD = 13'h2;
localparam rRTP = 13'h1;    // 读后到 PRECHARGE
localparam rWR  = 13'h1;    // tWR ~15 ns -> 1 拍

localparam tFresh = 9'd385;   // 50MHz: 7.7us

// #region 状态机
reg [3:0] nxt_status;
// 组合逻辑接口


localparam INIT0  = 4'h0;
localparam INIT1  = 4'h1;
localparam INIT2  = 4'h2;
localparam INIT3  = 4'h3;
localparam INIT4  = 4'h4;
localparam IDLE   = 4'h5;
localparam RUN0   = 4'h6;
localparam RUN1   = 4'h7;
localparam RUN2   = 4'h8;
localparam FRESH0 = 4'h9;
localparam FRESH1 = 4'ha;

reg [3:0] status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= INIT0;
    end
    else if (wait_time == 13'h0) begin
        status <= nxt_status;
    end
end
// #endregion



// #region 计时器
reg        wait_time_set;
reg [12:0] nxt_wait_time;
reg        refresh_time_set;
reg [8:0]  nxt_refresh_time;
// 组合逻辑接口


reg [12:0] wait_time;
reg [8:0]  refresh_time;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wait_time <= 13'h1fff;
        refresh_time <= 9'h0;
    end
    else begin
        if (wait_time_set) begin
            wait_time <= nxt_wait_time;
        end
        else if (wait_time != 13'h0) begin
            wait_time <= wait_time - 13'h1;
        end
        if (refresh_time_set) begin
            refresh_time <= nxt_refresh_time;
        end
        else if (refresh_time != 9'h0) begin
            refresh_time <= refresh_time - 9'h1;
        end
    end
end
// #endregion



// #region bank 活跃行号标记
reg        bank_active_set [3:0];
reg        nxt_bank_active [3:0];
reg [12:0] nxt_active_row [3:0];
// 组合逻辑接口


reg        bank_active [3:0];
reg [12:0] active_row  [3:0];

always @(posedge clk or negedge rst_n) begin : bank
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 4; i = i + 1) begin
            bank_active[i] <= 1'h0;
        end
    end
    else begin
        for (i = 0; i < 4; i = i + 1) begin
            if (bank_active_set[i]) begin
                bank_active[i] <= nxt_bank_active[i];
                active_row[i]  <= nxt_active_row[i];
            end
        end
    end
end
// #endregion



// #region 暂存请求
reg push;
// 组合逻辑接口

reg         p_we;
reg [15:0]  p_be;
reg [22:0]  p_addr;
reg [127:0] p_data;

always @(posedge clk) begin
    if (push) begin
        p_we <= request_we;
        p_be <= request_be;
        p_addr <= request_addr[22:0];
        p_data <= request_data;
    end
end
// #endregion



// #region 响应缓存
reg        nxt_valid;
reg [15:0] nxt_data;
// 组合逻辑接口


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_valid <= 1'h0;
    end
    else begin
        respond_valid <= nxt_valid;
        respond_data  <= nxt_data;
    end
end
// #endregion

task automatic set_wait_time(
    input [12:0] t
);
    wait_time_set = 1'h1;
    nxt_wait_time = t;
endtask

task automatic set_command(
    input [2:0] com
);
    sdram_ras_n_set = 1'h1;
    sdram_cas_n_set = 1'h1;
    sdram_we_n_set  = 1'h1;
    {nxt_sdram_ras_n, nxt_sdram_cas_n, nxt_sdram_we_n} = com;
endtask

task automatic nop();
    set_command(NOP);
endtask

task automatic precharge_all();
    integer i;
    begin
        set_wait_time(tRP);
        set_command(PRECHARGE);
        sdram_a_set = 1'h1;
        nxt_sdram_a = 13'h0400;
        for (i = 0; i < 4; i = i + 1) begin
            bank_active_set[i] = 1'h1;
            nxt_bank_active[i] = 1'h0;
        end
    end
endtask

task automatic auto_refresh();
    set_wait_time(tRFC);
    set_command(AUTO_REFRESH);
    // sdram_a_set = 1'h1;
    // nxt_sdram_a = 13'h0000;
endtask

task automatic load_mode_register(
    input [9:0] mode
);
    set_wait_time(tMRD);
    set_command(LOAD_MODE_REGISTER);
    // sdram_ba_set = 1'h1;
    // nxt_sdram_ba = 2'h0;
    sdram_a_set = 1'h1;
    nxt_sdram_a = {3'h0, mode};
endtask

task automatic read_begin(
    input [1:0] ba,
    input [8:0] a
);
    set_wait_time(tCL);
    set_command(READ);
    sdram_ba_set = 1'h1;
    nxt_sdram_ba = ba;
    sdram_a_set = 1'h1;
    nxt_sdram_a = {4'h0, a};
endtask

task automatic write_begin(
    input [1:0] ba,
    input [8:0] a
);
    set_wait_time(13'h7);
    set_command(WRITE);
    sdram_ba_set = 1'h1;
    nxt_sdram_ba = ba;
    sdram_a_set = 1'h1;
    nxt_sdram_a = {4'h0, a};
    // WRITE 命令拍同时输出第 0 拍；第 1..7 拍在 RUN2 的等待期间输出
    request(
        ~p_be[{p_addr[1:0], 2'h0} +: 2],
        p_data[{p_addr[1:0], 5'h0} +: 16]
    );
endtask

task automatic active(
    input [1:0] ba,
    input [12:0] a
);
    set_wait_time(tRCD);
    set_command(ACTIVE);
    sdram_ba_set = 1'h1;
    nxt_sdram_ba = ba;
    sdram_a_set = 1'h1;
    nxt_sdram_a = a;
    bank_active_set[ba] = 1'h1;
    nxt_bank_active[ba] = 1'h1;
    nxt_active_row[ba]  = a;
endtask

task automatic precharge(
    input [1:0] ba
);
    set_wait_time(tRP);
    set_command(PRECHARGE);
    sdram_ba_set = 1'h1;
    nxt_sdram_ba = ba;
    sdram_a_set = 1'h1;
    nxt_sdram_a = 13'h0;
    bank_active_set[ba] = 1'h1;
    nxt_bank_active[ba] = 1'h0;
endtask

task automatic respond(
    input [15:0] data
);
    nxt_valid = 1'h1;
    nxt_data = data;
endtask

task automatic request(
    input [1:0] dm,
    input [15:0] data
);
    sdram_dm_set = 1'h1;
    sdram_dq_out_set = 1'h1;
    nxt_sdram_dm = dm;
    nxt_sdram_dq_oe = 1'h1;
    nxt_sdram_dq_out = data;
endtask

always @(*) begin : comb
// #region 默认参数区
    integer i;
    request_busy     = 1'h1;
    nxt_sdram_dq_oe  = 1'h0;
    sdram_cke_set    = 1'h0;
    sdram_cs_n_set   = 1'h0;
    sdram_ras_n_set  = 1'h0;
    sdram_cas_n_set  = 1'h0;
    sdram_we_n_set   = 1'h0;
    sdram_ba_set     = 1'h0;
    sdram_dm_set     = 1'h0;
    sdram_a_set      = 1'h0;
    sdram_dq_out_set = 1'h0;
    nxt_sdram_cke    = 1'h0;
    nxt_sdram_cs_n   = 1'h1;
    nxt_sdram_ras_n  = 1'h1;
    nxt_sdram_cas_n  = 1'h1;
    nxt_sdram_we_n   = 1'h1;
    nxt_sdram_ba     = 2'h0;
    nxt_sdram_dm     = 2'h3;
    nxt_sdram_a      = 13'h0;
    nxt_sdram_dq_out = 16'h0;
    nxt_status       = status;
    wait_time_set    = 1'h0;
    nxt_wait_time    = 13'h0;
    refresh_time_set = 1'h0;
    nxt_refresh_time = 9'h0;
    push             = 1'h0;
    for (i = 0; i < 4; i = i + 1) begin
        bank_active_set[i] = 1'h0;
        nxt_bank_active[i] = 1'h0;
        nxt_active_row[i]  = 13'h0;
    end
    nxt_valid        = 1'h0;
    nxt_data         = 16'h0;
// #endregion
    if (wait_time != 13'h0) begin
        nop();
    end
    else begin
        case (status)
            INIT0: begin
                nxt_status = INIT1;
                set_wait_time(13'h0);
                sdram_cke_set = 1'h1;
                nxt_sdram_cke = 1'h1;
                sdram_cs_n_set = 1'h1;
                nxt_sdram_cs_n = 1'h0;
            end
            INIT1: begin
                nxt_status = INIT2;
                precharge_all();
            end
            INIT2: begin
                nxt_status = INIT3;
                auto_refresh();
            end
            INIT3: begin
                nxt_status = INIT4;
                auto_refresh();
            end
            INIT4: begin
                nxt_status = IDLE;
                load_mode_register(10'b0000100011);
                refresh_time_set = 1'h1;
                nxt_refresh_time = tFresh;
            end
            IDLE: begin
                if (refresh_time == 9'h0) begin
                    request_busy = 1'h1;
                    nxt_status = FRESH0;
                    nop();
                    set_wait_time(13'h0);
                end
                else begin
                    request_busy = 1'h0;
                    if (request_valid) begin
                        nxt_status = RUN0;
                        nop();
                        set_wait_time(13'h0);
                        push = 1'h1;
                    end
                    else begin
                        nxt_status = IDLE;
                        nop();
                        set_wait_time(13'h0);
                    end
                end
            end
            RUN0: begin
                if (bank_active[p_addr[3:2]]) begin
                    // 激活的行就是需要的
                    if (active_row[p_addr[3:2]] == p_addr[22:10]) begin
                        if (!p_we) begin
                            nxt_status = RUN1;
                            read_begin(p_addr[3:2], {p_addr[9:4], p_addr[1:0], 1'h0});
                        end
                        else begin
                            nxt_status = RUN2;
                            write_begin(p_addr[3:2], {p_addr[9:4], p_addr[1:0], 1'h0});
                        end
                    end
                    // 激活的行不是需要的
                    else begin
                        nxt_status = RUN0;
                        precharge(p_addr[3:2]);
                    end
                end
                // 行未激活
                else begin
                    nxt_status = RUN0;
                    active(p_addr[3:2], p_addr[22:10]);
                end
            end
            RUN1: begin
                nxt_status = RUN2;
                nop();
                set_wait_time(13'h7);
            end
            RUN2: begin
                nxt_status = IDLE;
                nop();
                // 读响应后等 rRTP；写 burst 后等 tWR
                set_wait_time(p_we ? rWR : rRTP);
            end
            FRESH0: begin
                if (
                    bank_active[0] || bank_active[1] ||
                    bank_active[2] || bank_active[3]
                ) begin
                    precharge_all();
                end
                else begin
                    nop();
                    set_wait_time(13'h0);
                end
                nxt_status = FRESH1;
            end
            FRESH1: begin
                nxt_status = IDLE;
                auto_refresh();
                refresh_time_set = 1'h1;
                nxt_refresh_time = tFresh;
            end
            default: ;
        endcase
    end
    case (status)
        RUN2: begin
            if (p_we) begin
                // write_begin 已经发了 beat0，这里只发 beat1..7
                // wait=7 → beat1, wait=6 → beat2, ... wait=1 → beat7
                if (wait_time != 13'h0) begin
                    request(
                        ~p_be[{{p_addr[1:0], 1'h0} + (3'h0 - wait_time[2:0]), 1'h0} +: 2],
                        p_data[{{p_addr[1:0], 1'h0} + (3'h0 - wait_time[2:0]), 4'h0} +: 16]
                    );
                end
            end
            else begin
                respond(sdram_dq_in);
            end
        end
        default: ;
    endcase
end

endmodule
