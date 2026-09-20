`timescale 1ns / 1ns

module uart_tx_unit #(
    parameter DIV = 25_000_000 / 115_200
) (
    input        clk,
    input        rst_n,
    input        start,
    input  [7:0] data,
    output       busy,
    output       tx
);

localparam IDLE   = 1'h0;
localparam ACTIVE = 1'h1;

reg        state;
reg [31:0] clk_cnt;
reg [3:0]  tx_idx;
reg [9:0]  tx_buf;

assign busy = state;
assign tx = tx_buf[tx_idx];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= IDLE;
        clk_cnt <= 32'h0;
        tx_idx  <= 4'h0;
        tx_buf  <= 10'h3ff;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state   <= ACTIVE;
                    tx_buf  <= {1'b1, data, 1'b0};
                end
            end

            ACTIVE: begin
                if (clk_cnt == DIV - 1) begin
                    clk_cnt <= 32'd0;
                    if (tx_idx == 4'h9) begin
                        state <= IDLE;
                        tx_idx <= 4'h0;
                        tx_buf  <= 10'h3ff;
                    end
                    else begin
                        tx_idx <= tx_idx + 4'h1;
                    end
                end
                else begin
                    clk_cnt <= clk_cnt + 32'h1;
                end
            end

            default: ;
        endcase
    end
end

endmodule
