`timescale 1ns / 1ns

// Clock/bus liveness check using the RESET-ed system_bus + uart_tx (no CPU).
// If this prints, the board-side bus path with the new reset tree is fine and
// the remaining problem is inside the CPU.
module top (
    input  clk,
    output led_r,
    output led_g,
    output led_b,
    output uart_tx
);

reg [31:0] cnt = 32'h0;
always @(posedge clk) cnt <= cnt + 32'd1;

reg [24:0] div = 25'h0;
reg        tick = 0;
always @(posedge clk) begin
    if (div == 25_000_001 - 1) begin
        div  <= 0;
        tick <= 1;
    end else begin
        div  <= div + 1;
        tick <= 0;
    end
end

reg [7:0] sample = 8'h0;
always @(posedge clk) if (tick) sample <= cnt[7:0];

reg [1:0] sub = 2'h0;
always @(posedge clk) if (tick) sub <= sub + 2'd1;

function [7:0] hexd(input [3:0] n);
    hexd = (n < 10) ? (8'h30 + n) : (8'h61 + n - 4'hA);
endfunction

reg [7:0] byte_val;
always @(*) begin
    case (sub)
        2'd0: byte_val = hexd(sample[7:4]);
        2'd1: byte_val = hexd(sample[3:0]);
        2'd2: byte_val = 8'h0d;
        default: byte_val = 8'h0a;
    endcase
end

reg req_valid = 0, req_write = 0;
reg [3:0] req_en = 0;
reg [31:0] req_data = 0;
always @(posedge clk) begin
    req_valid <= 0;
    req_write <= 0;
    req_en    <= 0;
    if (tick) begin
        req_valid <= 1;
        req_write <= 1;
        req_en    <= 4'h1;
        req_data  <= {24'h0, byte_val};
    end
end

reg        rst_n = 1'b0;
initial begin
    #200
    rst_n = 1'b1;            // 释放复位，与 syn/top.v 的 rst_cnt 等效
end

wire uart_tx_w;
system_bus system_bus (
    .clk                (clk),
    .rst_n              (rst_n),
    .request_valid_data (req_valid),
    .request_valid_instr(1'b0),
    .request_write_data (req_write),
    .request_en_data    (req_en),
    .request_addr_data  (32'hffc),
    .request_addr_instr (32'h0),
    .request_data_data  (req_data),
    .respond_fault_data (),
    .respond_fault_instr(),
    .respond_valid_data (),
    .respond_valid_instr(),
    .respond_data_data  (),
    .respond_data_instr (),
    .uart_tx            (uart_tx_w)
);
assign uart_tx = uart_tx_w;
assign led_r = req_valid;
assign led_g = tick;
assign led_b = cnt[23];

endmodule
