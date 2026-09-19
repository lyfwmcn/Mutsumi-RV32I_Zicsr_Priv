`timescale 1ns / 1ns

// iCESugar-Pro 板级顶层：CPU + system_bus（EBR 存储器）。
// CPU 的 request_* 直接接到 system_bus，system_bus 的 respond_* 回给 CPU。
module top (
    input  clk,
    output led_r,
    output led_g,
    output led_b,
    // 串口 TX → iCELink 的 USB CDC（管脚 B9）
    output uart_tx
);

// ---- CPU <-> system_bus 总线 ----
wire        request_valid_data;
wire        request_valid_instr;
wire        request_write_data;
wire [3:0]  request_en_data;
wire [31:0] request_addr_data;
wire [31:0] request_addr_instr;
wire [31:0] request_data_data;

wire        respond_fault_data;
wire        respond_fault_instr;
wire        respond_valid_data;
wire        respond_valid_instr;
wire [31:0] respond_data_data;
wire [31:0] respond_data_instr;

cpu cpu (
    .clk                     (clk),
    // 板上没有中断源，恒 0
    .external_interrupt_clear(1'b0),
    .external_interrupt_set  (1'b0),
    .timer_interrupt_clear   (1'b0),
    .timer_interrupt_set     (1'b0),

    .respond_fault_data      (respond_fault_data),
    .respond_fault_instr     (respond_fault_instr),
    .respond_valid_data      (respond_valid_data),
    .respond_valid_instr     (respond_valid_instr),
    .respond_data_data       (respond_data_data),
    .respond_data_instr      (respond_data_instr),

    .request_valid_data      (request_valid_data),
    .request_valid_instr     (request_valid_instr),
    .request_write_data      (request_write_data),
    .request_en_data         (request_en_data),
    .request_addr_data       (request_addr_data),
    .request_addr_instr      (request_addr_instr),
    .request_data_data       (request_data_data)
);

system_bus system_bus (
    .clk                (clk),
    .request_valid_data (request_valid_data),
    .request_valid_instr(request_valid_instr),
    .request_write_data (request_write_data),
    .request_en_data    (request_en_data),
    .request_addr_data  (request_addr_data),
    .request_addr_instr (request_addr_instr),
    .request_data_data  (request_data_data),

    .respond_fault_data (respond_fault_data),
    .respond_fault_instr(respond_fault_instr),
    .respond_valid_data (respond_valid_data),
    .respond_valid_instr(respond_valid_instr),
    .respond_data_data  (respond_data_data),
    .respond_data_instr (respond_data_instr),

    .uart_tx            (uart_tx)
);

// 三个 LED 先用总线活动指示（调试用）
assign led_r = request_valid_instr;
assign led_g = request_valid_data;
assign led_b = request_write_data;

endmodule
