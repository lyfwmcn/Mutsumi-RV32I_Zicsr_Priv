`timescale 1ns / 1ns

// CPU 子系统：core + uncore + device（存储器子系统）
//
// 单独拆出来是为了让板级顶层(top.v)和仿真平台(tb_boot)用**同一份**接线，
// 避免"仿真过的东西和上板的东西不一样"。
//
// 复位/上电顺序：
//   rst_n 放开 → CPU 直接从固定 ROM（地址 0 ~ 4K）取指执行，不加载 SDRAM。
//   ROM 由 device 路由：0~4K 只读，SDRAM 的最低 4K 因此不再使用。
//   存储器侧（路由 / 仲裁 / SDRAM 控制器 / PHY / ROM / null / UART）全部在 device 里。
module cpu_subsys #(
    parameter SYS_HZ = 50_000_000        // 系统时钟，UART 分频用
) (
    input         clk,
    input         rst_n,

    // SDRAM 引脚
    output        sdram_cke,
    output        sdram_cs_n,
    output        sdram_ras_n,
    output        sdram_cas_n,
    output        sdram_we_n,
    output [1:0]  sdram_ba,
    output [12:0] sdram_a,
    inout  [15:0] sdram_dq,
    output [1:0]  sdram_dm,

    // UART
    output        uart_tx,
    input         uart_rx,

    // 调试观察
    output        boot_done,
    output [1:0]  privilege,
    output [31:0] satp,

    // 上板调试用（给 LED）：CPU 是否在退休指令 / 设备写是否在发生
    output        dbg_cpu,        // 有设备写 -> ~3Hz 翻转
    output        dbg_vfy,        // 保留（现在恒 0）
    output        dbg_uart,       // 有设备写(UART) -> 慢闪
    output        dbg_blink       // 保留（现在恒 0）
);

    // ------------------------------ CPU <-> uncore ------------------------------
    wire        d_af, d_busy, d_pf, d_rv;
    wire [31:0] d_rd;
    wire        d_valid;
    wire [1:0]  d_op;
    wire [3:0]  d_be;
    wire [29:0] d_addr;
    wire [31:0] d_wdata;
    wire        i_af, i_busy, i_pf, i_rv;
    wire [31:0] i_rd;
    wire        i_valid;
    wire [29:0] i_addr;

    // --------------------------- uncore <-> device ---------------------------
    wire        c_d_busy, c_d_rv;
    wire [15:0] c_d_rd;
    wire        c_d_valid, c_d_we;
    wire [15:0] c_d_be;
    wire [32:0] c_d_addr;
    wire [127:0] c_d_data;

    wire        c_i_busy, c_i_rv;
    wire [15:0] c_i_rd;
    wire        c_i_valid;
    wire [32:0] c_i_addr;

    // 没有加载阶段，CPU 侧复位直接跟随系统复位
    wire rst_n_cpu = rst_n;

    // ------------------------------ core / uncore ------------------------------
    core u_core (
        .clk(clk), .rst_n(rst_n_cpu),
        .external_interrupt_clear(1'b0), .external_interrupt_set(1'b0),
        .timer_interrupt_clear(1'b0),    .timer_interrupt_set(1'b0),
        .d_core_respond_access_fault(d_af), .d_core_respond_page_fault(d_pf),
        .d_core_respond_valid(d_rv), .d_core_respond_data(d_rd),
        .d_core_request_busy(d_busy),
        .d_core_request_valid(d_valid), .d_core_request_op(d_op), .d_core_request_be(d_be),
        .d_core_request_addr(d_addr), .d_core_request_data(d_wdata),
        .i_core_respond_access_fault(i_af), .i_core_respond_page_fault(i_pf),
        .i_core_respond_valid(i_rv), .i_core_respond_data(i_rd),
        .i_core_request_busy(i_busy),
        .i_core_request_valid(i_valid), .i_core_request_addr(i_addr),
        .satp(satp), .privilege(privilege)
    );

    uncore u_uncore (
        .clk(clk), .rst_n(rst_n_cpu),
        .privilege(privilege), .satp(satp),
        .d_core_request_valid(d_valid), .d_core_request_op(d_op), .d_core_request_be(d_be),
        .d_core_request_vaddr(d_addr), .d_core_request_data(d_wdata),
        .d_core_respond_access_fault(d_af), .d_core_request_busy(d_busy),
        .d_core_respond_page_fault(d_pf), .d_core_respond_valid(d_rv), .d_core_respond_data(d_rd),
        .i_core_request_valid(i_valid), .i_core_request_vaddr(i_addr),
        .i_core_respond_access_fault(i_af), .i_core_request_busy(i_busy),
        .i_core_respond_page_fault(i_pf), .i_core_respond_valid(i_rv), .i_core_respond_data(i_rd),
        .d_ram_request_busy(c_d_busy), .d_ram_respond_valid(c_d_rv), .d_ram_respond_data(c_d_rd),
        .d_ram_request_valid(c_d_valid), .d_ram_request_we(c_d_we), .d_ram_request_be(c_d_be),
        .d_ram_request_addr(c_d_addr), .d_ram_request_data(c_d_data),
        .i_ram_request_busy(c_i_busy), .i_ram_respond_valid(c_i_rv), .i_ram_respond_data(c_i_rd),
        .i_ram_request_valid(c_i_valid), .i_ram_request_addr(c_i_addr)
    );

    // ------------------------- 存储器子系统（路由/仲裁/ROM/SDRAM/UART）---------
    device #(.SYS_HZ(SYS_HZ)) u_device (
        .clk(clk), .rst_n(rst_n),

        .d_cache_request_valid(c_d_valid), .d_cache_request_we(c_d_we),
        .d_cache_request_be(c_d_be), .d_cache_request_addr(c_d_addr),
        .d_cache_request_data(c_d_data),
        .d_cache_request_busy(c_d_busy), .d_cache_respond_valid(c_d_rv),
        .d_cache_respond_data(c_d_rd),

        .i_cache_request_valid(c_i_valid), .i_cache_request_addr(c_i_addr),
        .i_cache_request_busy(c_i_busy), .i_cache_respond_valid(c_i_rv),
        .i_cache_respond_data(c_i_rd),

        .sdram_cke(sdram_cke), .sdram_cs_n(sdram_cs_n), .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_ba(sdram_ba),
        .sdram_a(sdram_a), .sdram_dq(sdram_dq), .sdram_dm(sdram_dm),

        .uart_tx(uart_tx), .uart_rx(uart_rx)
    );

    assign boot_done = 1'b1;   // 没有加载阶段，复位放开即视为"已就绪"

    // --------------------------- 调试计数（给 LED） ---------------------------
    // 程序每往设备区写一次加一，取高位翻转
    wire dev_wr = c_d_valid && !c_d_busy && c_d_we &&
                  (c_d_addr[32:25] == 8'h0) && c_d_addr[24];

    reg [23:0] cpu_beat;
    always @(posedge clk or negedge rst_n_cpu) begin
        if (!rst_n_cpu) cpu_beat <= 24'h0;
        else if (dev_wr) cpu_beat <= cpu_beat + 24'h1;
    end
    assign dbg_cpu = cpu_beat[9];

    reg [23:0] uart_beat;
    always @(posedge clk or negedge rst_n_cpu) begin
        if (!rst_n_cpu)     uart_beat <= 24'h0;
        else if (dev_wr)    uart_beat <= uart_beat + 24'h1;
    end
    assign dbg_uart = uart_beat[9];

    assign dbg_vfy   = 1'b0;      // 保留端口（没有加载器了）
    assign dbg_blink = 1'b0;

endmodule
