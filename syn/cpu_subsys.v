`timescale 1ns / 1ns

// CPU 子系统：core + uncore + device（存储器子系统）
//
// 和 cpu_subsys 的差别：
//   - 外部/定时器中断的 clear/set 直接引到端口，方便测试注入；
//   - 不输出调试观察信号，也不接 uart_rx；
//   - 其余 core / uncore / device 连线保持一致。
module cpu_subsys #(
    parameter SYS_HZ = 50_000_000
) (
    input          clk,
    input          rst_n,

    input          external_interrupt_clear,
    input          external_interrupt_set,
    input          timer_interrupt_clear,
    input          timer_interrupt_set,

    output         sdram_cke,
    output         sdram_cs_n,
    output         sdram_ras_n,
    output         sdram_cas_n,
    output         sdram_we_n,
    output [1:0]   sdram_ba,
    output [1:0]   sdram_dm,
    output [12:0]  sdram_a,
    inout  [15:0]  sdram_dq,

    output         uart_tx
);

// ------------------------------ CPU <-> uncore ------------------------------
wire        d_req_busy_1;
wire        d_res_af_1;
wire        d_res_pf_1;
wire        d_res_valid_1;
wire [31:0] d_res_data_1;
wire        d_req_valid_1;
wire [1:0]  d_req_op_1;
wire [3:0]  d_req_be_1;
wire [29:0] d_req_addr_1;
wire [31:0] d_req_data_1;

wire        i_req_busy_1;
wire        i_res_af_1;
wire        i_res_pf_1;
wire        i_res_valid_1;
wire [31:0] i_res_data_1;
wire        i_req_valid_1;
wire [29:0] i_req_addr_1;

wire [1:0]  privilege;
wire [31:0] satp;

// --------------------------- uncore <-> device ---------------------------
wire        d_req_busy_2;
wire        d_res_valid_2;
wire [15:0] d_res_data_2;
wire        d_req_valid_2;
wire        d_req_we_2;
wire [15:0] d_req_be_2;
wire [31:0] d_req_addr_2;
wire [127:0] d_req_data_2;

wire        i_req_busy_2;
wire        i_res_valid_2;
wire [15:0] i_res_data_2;
wire        i_req_valid_2;
wire [31:0] i_req_addr_2;

core u_core (
    .clk                        (clk),
    .rst_n                      (rst_n),

    .external_interrupt_clear   (external_interrupt_clear),
    .external_interrupt_set     (external_interrupt_set),
    .timer_interrupt_clear      (timer_interrupt_clear),
    .timer_interrupt_set        (timer_interrupt_set),

    .privilege                  (privilege),
    .satp                       (satp),

    .d_core_request_busy        (d_req_busy_1),
    .d_core_respond_access_fault(d_res_af_1),
    .d_core_respond_page_fault  (d_res_pf_1),
    .d_core_respond_valid       (d_res_valid_1),
    .d_core_respond_data        (d_res_data_1),
    .d_core_request_valid       (d_req_valid_1),
    .d_core_request_op          (d_req_op_1),
    .d_core_request_be          (d_req_be_1),
    .d_core_request_addr        (d_req_addr_1),
    .d_core_request_data        (d_req_data_1),

    .i_core_request_busy        (i_req_busy_1),
    .i_core_respond_access_fault(i_res_af_1),
    .i_core_respond_page_fault  (i_res_pf_1),
    .i_core_respond_valid       (i_res_valid_1),
    .i_core_respond_data        (i_res_data_1),
    .i_core_request_valid       (i_req_valid_1),
    .i_core_request_addr        (i_req_addr_1)
);

uncore u_uncore (
    .clk                        (clk),
    .rst_n                      (rst_n),

    .privilege                  (privilege),
    .satp                       (satp),

    .d_core_request_valid       (d_req_valid_1),
    .d_core_request_op          (d_req_op_1),
    .d_core_request_be          (d_req_be_1),
    .d_core_request_vaddr       (d_req_addr_1),
    .d_core_request_data        (d_req_data_1),
    .d_core_request_busy        (d_req_busy_1),
    .d_core_respond_access_fault(d_res_af_1),
    .d_core_respond_page_fault  (d_res_pf_1),
    .d_core_respond_valid       (d_res_valid_1),
    .d_core_respond_data        (d_res_data_1),

    .i_core_request_valid       (i_req_valid_1),
    .i_core_request_vaddr       (i_req_addr_1),
    .i_core_respond_access_fault(i_res_af_1),
    .i_core_request_busy        (i_req_busy_1),
    .i_core_respond_page_fault  (i_res_pf_1),
    .i_core_respond_valid       (i_res_valid_1),
    .i_core_respond_data        (i_res_data_1),

    .d_ram_request_busy         (d_req_busy_2),
    .d_ram_respond_valid        (d_res_valid_2),
    .d_ram_respond_data         (d_res_data_2),
    .d_ram_request_valid        (d_req_valid_2),
    .d_ram_request_we           (d_req_we_2),
    .d_ram_request_be           (d_req_be_2),
    .d_ram_request_addr         (d_req_addr_2),
    .d_ram_request_data         (d_req_data_2),

    .i_ram_request_busy         (i_req_busy_2),
    .i_ram_respond_valid        (i_res_valid_2),
    .i_ram_respond_data         (i_res_data_2),
    .i_ram_request_valid        (i_req_valid_2),
    .i_ram_request_addr         (i_req_addr_2)
);

device #(
    .SYS_HZ(SYS_HZ)
) u_device (
    .clk                        (clk),
    .rst_n                      (rst_n),

    .d_uncore_request_valid     (d_req_valid_2),
    .d_uncore_request_we        (d_req_we_2),
    .d_uncore_request_be        (d_req_be_2),
    .d_uncore_request_addr      (d_req_addr_2),
    .d_uncore_request_data      (d_req_data_2),
    .d_uncore_request_busy      (d_req_busy_2),
    .d_uncore_respond_valid     (d_res_valid_2),
    .d_uncore_respond_data      (d_res_data_2),

    .i_uncore_request_valid     (i_req_valid_2),
    .i_uncore_request_addr      (i_req_addr_2),
    .i_uncore_request_busy      (i_req_busy_2),
    .i_uncore_respond_valid     (i_res_valid_2),
    .i_uncore_respond_data      (i_res_data_2),

    .sdram_cke                  (sdram_cke),
    .sdram_cs_n                 (sdram_cs_n),
    .sdram_ras_n                (sdram_ras_n),
    .sdram_cas_n                (sdram_cas_n),
    .sdram_we_n                 (sdram_we_n),
    .sdram_ba                   (sdram_ba),
    .sdram_dm                   (sdram_dm),
    .sdram_a                    (sdram_a),
    .sdram_dq                   (sdram_dq),

    .uart_tx                    (uart_tx)
);

endmodule
