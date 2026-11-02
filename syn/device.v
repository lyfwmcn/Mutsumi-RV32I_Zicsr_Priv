`timescale 1ns / 1ns

// 存储器子系统：地址路由 + SDRAM 仲裁 + SDRAM 控制器/PHY + ROM + null + UART
//
// 对外只留两组接口：
//   1) uncore 的 d_cache / i_cache 请求口
//   2) 板级引脚（SDRAM / UART）
//
// 地址映射（字节地址）：
//   0x0000_0000 ~ 0x0000_0FFF  固定 ROM（4KB，只读，内容 = build/boot.hex）
//   0x0000_1000 ~ 0x01FF_FFFF  SDRAM（pma==1）
//   0x0200_0000 ~ 0x3FFF_FFFF  Device（pma==2，只有 d_cache 写 → uart）
//   其他                       pma==0（uncore 直接回 access fault）
//
// 路由规则：
//   i_cache（只读）: ROM 区        → ROM 口
//                    pma == 1     → SDRAM（进仲裁）
//                    pma == 0/2   → null_device（读回 0）
//   d_cache（读写）: ROM 区 读     → ROM 口
//                    ROM 区 写     → null_device（写丢弃、无响应）
//                    pma == 1     → SDRAM（进仲裁）
//                    pma == 2     → uart（写）/ 8 拍 0（读）
//                    pma == 0     → null_device
//
// SDRAM 仲裁：
//   - d / i 各有一个 pending 槽，请求是"单拍脉冲"，所以必须来者不拒地锁存；
//   - request_busy 用"槽位被占"的寄存器（不能用 request_valid 组合出来，
//     否则会和 uncore 的 `if (!busy) 发请求` 形成组合环）；
//   - 同一时刻只有一笔事务在 sdram_ctr 上，响应 8 拍按 cur 送回对应口；
//   - 仲裁优先级：d 优先。
module device #(
    parameter SYS_HZ = 50_000_000        // 系统时钟，UART 分频用
) (
    input             clk,
    input             rst_n,

    // ---------------- 请求方：d_cache（读写）----------------
    input             d_cache_request_valid,
    input             d_cache_request_we,
    input      [15:0] d_cache_request_be,
    input      [32:0] d_cache_request_addr,
    input      [127:0] d_cache_request_data,
    output            d_cache_request_busy,
    output            d_cache_respond_valid,
    output     [15:0] d_cache_respond_data,

    // ---------------- 请求方：i_cache（只读）----------------
    input             i_cache_request_valid,
    input      [32:0] i_cache_request_addr,
    output            i_cache_request_busy,
    output            i_cache_respond_valid,
    output     [15:0] i_cache_respond_data,

    // ---------------- SDRAM 引脚 ----------------
    output            sdram_cke,
    output            sdram_cs_n,
    output            sdram_ras_n,
    output            sdram_cas_n,
    output            sdram_we_n,
    output     [1:0]  sdram_ba,
    output     [12:0] sdram_a,
    inout      [15:0] sdram_dq,
    output     [1:0]  sdram_dm,

    // ---------------- UART 引脚 ----------------
    output            uart_tx,
    input             uart_rx
);

// ---------------- pma：0=未映射 1=SDRAM 2=Device ----------------
function automatic [1:0] pma;
    input [32:0] addr; // 以 2 字节为单位的地址
    reg   [33:0] baddr;
    begin
        baddr = {addr, 1'h0};
        pma   = baddr[33:26] != 8'h0 ? 2'h0 :
                !baddr[25]           ? 2'h1 : 2'h2;
    end
endfunction

// 字节地址（33 位 addr 左移 1 位）
wire [33:0] baddr_d = {d_cache_request_addr, 1'h0};
wire [33:0] baddr_i = {i_cache_request_addr, 1'h0};

// ROM 区：字节地址 < 4KB
wire        is_rom_d = (baddr_d[33:12] == 22'h0);
wire        is_rom_i = (baddr_i[33:12] == 22'h0);

wire [1:0] pma_i_cache = pma(i_cache_request_addr);
wire [1:0] pma_d_cache = pma(d_cache_request_addr);

// ---------------- 固定 ROM（0 ~ 4K）----------------
// boot_rom 自带请求接口：单拍 valid 进来，锁地址 -> 同步读 EBR -> 连续 8 拍返回 16 位数据。
// request_addr 是"2 字节单位"的地址（4KB = 2048 字 -> 11 位），
// 行号 = addr[10:3]，行内 16 位字偏移 = addr[2:0]。
// i / d 各一份（EBR 各 4 块），这样取指和读常数可以并行。
wire        rom_d_busy, rom_d_rv;
wire [15:0] rom_d_rd;
wire        rom_i_busy, rom_i_rv;
wire [15:0] rom_i_rd;

wire        rom_d_valid = d_cache_request_valid && is_rom_d && !d_cache_request_we;
wire        rom_i_valid = i_cache_request_valid && is_rom_i;

boot_rom u_rom_d (
    .clk(clk), .rst_n(rst_n),
    .request_valid(rom_d_valid),
    .request_we(d_cache_request_we),
    .request_be(d_cache_request_be),
    .request_addr(baddr_d[11:1]),      // 字节地址 -> 2 字节单位
    .request_data(d_cache_request_data),
    .request_busy(rom_d_busy),
    .respond_valid(rom_d_rv),
    .respond_data(rom_d_rd)
);

boot_rom u_rom_i (
    .clk(clk), .rst_n(rst_n),
    .request_valid(rom_i_valid),
    .request_we(1'h0),                 // i 侧只读
    .request_be(16'h0),
    .request_addr(baddr_i[11:1]),
    .request_data(128'h0),
    .request_busy(rom_i_busy),
    .respond_valid(rom_i_rv),
    .respond_data(rom_i_rd)
);

// ---------------- 设备侧（null / uart）信号 ----------------
wire        n_ic_busy, n_ic_rv;
wire [15:0] n_ic_rd;
wire        n_dc_busy, n_dc_rv;
wire [15:0] n_dc_rd;

wire        n_ic_valid, n_dc_valid;
wire        u_busy, u_rv;
wire [15:0] u_rd;
wire        u_valid;

// ---------------- 空设备：i / d 各一个（同一种从设备接口）----------------
null_device u_null_i (
    .clk(clk), .rst_n(rst_n),
    .request_valid(n_ic_valid),
    .request_we(1'h0),                 // i 侧只读
    .request_be(16'h0),
    .request_addr(i_cache_request_addr[23:0]),
    .request_data(128'h0),
    .request_busy(n_ic_busy),
    .respond_valid(n_ic_rv),
    .respond_data(n_ic_rd)
);

null_device u_null_d (
    .clk(clk), .rst_n(rst_n),
    .request_valid(n_dc_valid),
    .request_we(d_cache_request_we),
    .request_be(d_cache_request_be),
    .request_addr(d_cache_request_addr[23:0]),
    .request_data(d_cache_request_data),
    .request_busy(n_dc_busy),
    .respond_valid(n_dc_rv),
    .respond_data(n_dc_rd)
);

// ---------------- uart（只挂 d_cache 写，pma==2）----------------
uart_tx_unit #(.DIV(SYS_HZ / 115_200)) u_uart (
    .clk(clk),
    .rst_n(rst_n),
    .request_valid(u_valid),
    .request_we(d_cache_request_we),
    .request_be(d_cache_request_be),
    .request_data(d_cache_request_data),
    .request_busy(u_busy),
    .respond_valid(u_rv),
    .respond_data(u_rd),
    .tx(uart_tx)
);

// ---------------- 极简 UART 接收（留给以后的引导程序用，现在只置标志）----------------
localparam integer RX_DIV = SYS_HZ / 115_200;
localparam [1:0] RX_IDLE = 2'h0, RX_START = 2'h1, RX_DATA = 2'h2, RX_STOP = 2'h3;
reg [1:0] rx_st;
integer   rx_cnt;
reg [2:0] rx_bit;
reg [7:0] rx_sh;
reg       rx_got;      // 收到过至少一个字节

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_st  <= RX_IDLE;
        rx_cnt <= 0;
        rx_bit <= 3'h0;
        rx_sh  <= 8'h0;
        rx_got <= 1'b0;
    end
    else begin
        case (rx_st)
            RX_IDLE:  if (!uart_rx) begin rx_st <= RX_START; rx_cnt <= RX_DIV/2; end
            RX_START: if (rx_cnt == 0) begin rx_st <= RX_DATA; rx_bit <= 3'h0; rx_cnt <= RX_DIV-1; end
                      else rx_cnt <= rx_cnt - 1;
            RX_DATA:  if (rx_cnt == 0) begin
                          rx_sh[rx_bit] <= uart_rx;
                          rx_cnt <= RX_DIV - 1;
                          if (rx_bit == 3'h7) rx_st <= RX_STOP;
                          else                rx_bit <= rx_bit + 3'h1;
                      end
                      else rx_cnt <= rx_cnt - 1;
            RX_STOP:  if (rx_cnt == 0) begin rx_st <= RX_IDLE; if (uart_rx) rx_got <= 1'b1; end
                      else rx_cnt <= rx_cnt - 1;
            default: rx_st <= RX_IDLE;
        endcase
    end
end

// ---------------- SDRAM 仲裁：d / i 各一个槽位 ----------------
reg         pend_d, pend_i;
reg         pend_we_d;
reg  [15:0] pend_be_d;
reg  [23:0] pend_addr_d;
reg [127:0] pend_data_d;
reg  [23:0] pend_addr_i;

// 请求方想访问 SDRAM（pma==1 且不在 ROM 区）
wire d_sdram = d_cache_request_valid && !is_rom_d && (pma_d_cache == 2'h1);
wire i_sdram = i_cache_request_valid && !is_rom_i && (pma_i_cache == 2'h1);

// busy 用槽位寄存器（不能组合依赖 request_valid，否则和 uncore 成环）
assign d_cache_request_busy = rom_d_busy | u_busy | n_dc_busy | pend_d;
assign i_cache_request_busy = rom_i_busy | n_ic_busy | pend_i;

// 正在服务哪个槽位：0 = d，1 = i
reg  cur_valid;
reg  cur;

// 仲裁器 -> sdram_ctr 的单口
wire         ram_valid, ram_we, ram_busy, ram_rv;
wire [15:0]  ram_be, ram_rd;
wire [23:0]  ram_addr;
wire [127:0] ram_data;

wire issue = !cur_valid && !ram_busy && (pend_d || pend_i);

// 事务结束：sdram_ctr 的 request_busy 落回 0（写没有响应，只能这么判）。
// 发起那一拍 cur_valid 还是 0，所以不会在发请求的当拍误判。
wire ram_done = cur_valid && !ram_busy;

assign ram_valid = issue;
assign ram_addr  = pend_d ? pend_addr_d : pend_addr_i;
assign ram_we    = pend_d ? pend_we_d   : 1'h0;
assign ram_be    = pend_d ? pend_be_d   : 16'h0;
assign ram_data  = pend_d ? pend_data_d : 128'h0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pend_d       <= 1'h0;
        pend_i       <= 1'h0;
        pend_we_d    <= 1'h0;
        pend_be_d    <= 16'h0;
        pend_addr_d  <= 24'h0;
        pend_data_d  <= 128'h0;
        pend_addr_i  <= 24'h0;
        cur_valid    <= 1'h0;
        cur          <= 1'h0;
    end
    else begin
        // 锁存新请求（单拍脉冲，槽位空才收）
        if (d_sdram && !pend_d) begin
            pend_d      <= 1'h1;
            pend_we_d   <= d_cache_request_we;
            pend_be_d   <= d_cache_request_be;
            pend_addr_d <= d_cache_request_addr[23:0];
            pend_data_d <= d_cache_request_data;
        end
        if (i_sdram && !pend_i) begin
            pend_i      <= 1'h1;
            pend_addr_i <= i_cache_request_addr[23:0];
        end

        // 事务开始 / 结束
        if (issue) begin
            cur_valid <= 1'h1;
            cur       <= pend_d ? 1'b0 : 1'b1;   // d 优先
        end
        else if (ram_done) begin
            cur_valid <= 1'h0;
            if (!cur) pend_d <= 1'h0;
            else      pend_i <= 1'h0;
        end
    end
end

// ---------------- SDRAM 控制器 + PHY ----------------
wire        ctr_cke, ctr_cs_n, ctr_ras_n, ctr_cas_n, ctr_we_n;
wire [1:0]  ctr_ba, ctr_dm;
wire [12:0] ctr_a;
wire [15:0] ctr_dq_out, ctr_dq_in;
wire        ctr_dq_oe;

sdram_ctr u_sdram (
    .clk(clk), .rst_n(rst_n),
    .request_valid(ram_valid), .request_we(ram_we), .request_be(ram_be),
    .request_addr(ram_addr), .request_data(ram_data),
    .request_busy(ram_busy), .respond_valid(ram_rv), .respond_data(ram_rd),
    .sdram_cke(ctr_cke), .sdram_cs_n(ctr_cs_n), .sdram_ras_n(ctr_ras_n),
    .sdram_cas_n(ctr_cas_n), .sdram_we_n(ctr_we_n), .sdram_ba(ctr_ba),
    .sdram_dm(ctr_dm), .sdram_a(ctr_a),
    .sdram_dq_out(ctr_dq_out), .sdram_dq_oe(ctr_dq_oe), .sdram_dq_in(ctr_dq_in)
);

sdram_phy_ecp5 #(.USE_PIC(1)) u_sdram_phy (
    .clk(clk), .rst_n(rst_n),
    .cke_in(ctr_cke), .cs_n_in(ctr_cs_n), .ras_n_in(ctr_ras_n),
    .cas_n_in(ctr_cas_n), .we_n_in(ctr_we_n),
    .ba_in(ctr_ba), .a_in(ctr_a), .dm_in(ctr_dm),
    .dq_out_in(ctr_dq_out), .dq_oe_in(ctr_dq_oe), .dq_in(ctr_dq_in),
    .sdram_cke(sdram_cke), .sdram_cs_n(sdram_cs_n), .sdram_ras_n(sdram_ras_n),
    .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_ba(sdram_ba),
    .sdram_dm(sdram_dm), .sdram_a(sdram_a), .sdram_dq(sdram_dq)
);

// ---------------- i_cache：ROM → ROM 口；pma==1 → SDRAM 仲裁；否则 → null ----------------
assign n_ic_valid = i_cache_request_valid && !is_rom_i && (pma_i_cache != 2'h1);

wire i_ram_respond_sel = ram_rv && cur_valid && cur;

assign i_cache_respond_valid = i_ram_respond_sel | rom_i_rv | n_ic_rv;
assign i_cache_respond_data  = i_ram_respond_sel ? ram_rd :
                               (rom_i_rv ? rom_i_rd : n_ic_rd);

// ---------------- d_cache：ROM 读 → ROM 口；写/其余按 pma ----------------
// ROM 区写：走 null（1 拍完成、无响应，直接丢弃）
wire d_rom_wr = d_cache_request_valid && is_rom_d && d_cache_request_we;

assign u_valid = d_cache_request_valid && !is_rom_d && (pma_d_cache == 2'h2);

assign n_dc_valid = d_rom_wr ||
                    (d_cache_request_valid && !is_rom_d && (pma_d_cache == 2'h0));

wire d_ram_respond_sel = ram_rv && cur_valid && !cur;

assign d_cache_respond_valid = d_ram_respond_sel | rom_d_rv | u_rv | n_dc_rv;
assign d_cache_respond_data  = d_ram_respond_sel ? ram_rd :
                               (rom_d_rv ? rom_d_rd :
                               (u_rv ? u_rd : n_dc_rd));

endmodule
