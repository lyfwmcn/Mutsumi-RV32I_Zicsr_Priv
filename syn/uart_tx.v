`timescale 1ns / 1ns

// UART 8N1 transmitter, following the official iCESugar example:
// one 10-bit frame is shifted LSB first (start, 8 data bits, stop).
// rst_n is the project-wide active-low asynchronous reset.
module uart_tx #(
    parameter DIV = 25_000_000 / 115_200
) (
    input        clk,
    input        rst_n,
    input        start,             // one-cycle pulse while idle
    input  [7:0] data,
    output reg   busy,
    output       tx
);

localparam IDLE   = 1'b0;
localparam ACTIVE = 1'b1;

reg       state;
reg [8:0] clk_cnt;
reg [3:0] tx_idx;
reg [9:0] tx_buf;

// The current frame bit is combinational, as in the official example.
assign tx = (state == IDLE) ? 1'b1 : tx_buf[0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= IDLE;
        clk_cnt <= 9'd0;
        tx_idx  <= 4'd0;
        tx_buf  <= 10'b11_1111_1111;
        busy    <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    // {stop, data[7:0], start}; tx_buf[0] is the start bit.
                    tx_buf  <= {1'b1, data, 1'b0};
                    tx_idx  <= 4'd0;
                    clk_cnt <= 9'd0;
                    busy    <= 1'b1;
                    state   <= ACTIVE;
                end
            end

            ACTIVE: begin
                busy <= 1'b1;
                if (clk_cnt == DIV - 1) begin
                    clk_cnt <= 9'd0;
                    if (tx_idx == 4'd9) begin
                        // The stop bit has just completed.
                        state <= IDLE;
                        busy  <= 1'b0;
                    end
                    else begin
                        tx_buf <= {1'b0, tx_buf[9:1]};
                        tx_idx <= tx_idx + 4'd1;
                    end
                end
                else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            default: begin
                state   <= IDLE;
                clk_cnt <= 9'd0;
                tx_idx  <= 4'd0;
                tx_buf  <= 10'b11_1111_1111;
                busy    <= 1'b0;
            end
        endcase
    end
end

endmodule
