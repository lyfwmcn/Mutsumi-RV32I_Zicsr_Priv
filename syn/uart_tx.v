`timescale 1ns / 1ns

// UART 8N1 发射器，LSB first，以系统时钟分频产生波特率。
// start 为单周期脉冲（busy 空闲时有效）；busy 高表示正在发送。
// 时序：start 位/数据位/停止位各占 DIV 个时钟；每个 cnt==DIV-1 边界移位一次。
module uart_tx #(
    parameter DIV = 25_000_000 / 115_200   // 每 bit 的时钟数 (217)
) (
    input clk,
    input rst_n,
    input start,
    input [7:0] data,
    output reg busy,
    output reg tx
);

localparam IDLE   = 2'd0;
localparam ACTIVE = 2'd1;

reg [31:0] cnt;
reg [1:0] state;
reg [3:0] bits;     // 已发出的数据位数 0..8，之后为停止位阶段
reg [7:0] sh;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        tx    <= 1'b1;
        busy  <= 1'b0;
        bits  <= 4'd0;
        sh    <= 8'h0;
        cnt   <= 32'd0;
    end
    else case (state)
        IDLE: begin
            busy <= 1'b0;
            tx   <= 1'b1;
            if (start) begin
                state <= ACTIVE;
                busy  <= 1'b1;
                bits  <= 4'd0;
                sh    <= data;
                cnt   <= 32'd0;
                tx    <= 1'b0;      // 起始位：持续到第一个 cnt==DIV-1 边界
            end
        end
        ACTIVE: begin
            cnt <= (cnt == DIV - 1) ? 32'd0 : cnt + 32'd1;
            if (cnt == DIV - 1) begin
                if (bits < 8) begin
                    tx  <= sh[0];
                    sh  <= {1'b0, sh[7:1]};
                    bits <= bits + 1'b1;
                end
                else if (bits == 8) begin
                    tx   <= 1'b1;   // 停止位
                    bits <= bits + 1'b1;
                end
                else begin
                    state <= IDLE;
                    busy  <= 1'b0;
                    tx    <= 1'b1;
                end
            end
        end
        default:begin
            state = IDLE;
            tx    = 1'b1;
            busy  = 1'b0;
            bits  = 4'd0;
            sh    = 8'h0;
            cnt   = 32'd0;
        end
    endcase
end

endmodule
