`timescale 1ns / 1ns

// 空设备（黑洞）：读永远返回 0，写直接丢弃
//
// 接口和 boot_rom / sdram_ctr 一致：
//   request_valid/we/be/addr/data 进；
//   request_busy 高到事务结束（读 8 拍 / 写 1 拍）；
//   读的 8 拍走 respond_valid + respond_data（全 0），写不产生响应。
//
// 注：模块不能叫 null（SystemVerilog 关键字，verilator 会报语法错），故用 null_device。
module null_device (
    input              clk,
    input              rst_n,

    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [23:0]  request_addr,
    input      [127:0] request_data,
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data
);

    localparam IDLE = 2'h0;
    localparam RD   = 2'h1;   // 读：连续 8 拍返回 0
    localparam WR   = 2'h2;   // 写：1 拍完成、无响应

    reg [1:0] status;
    reg [2:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status        <= IDLE;
            cnt           <= 3'h0;
            request_busy  <= 1'h0;
            respond_valid <= 1'h0;
            respond_data  <= 16'h0;
        end
        else begin
            case (status)
                IDLE: begin
                    if (request_valid) begin
                        request_busy <= 1'h1;
                        if (request_we) begin
                            // 写：下一拍就结束
                            status <= WR;
                        end
                        else begin
                            // 读：连续 8 拍返回 0
                            status        <= RD;
                            respond_valid <= 1'h1;
                            respond_data  <= 16'h0;
                            cnt           <= 3'h0;
                        end
                    end
                end
                RD: begin
                    if (cnt == 3'h7) begin
                        respond_valid <= 1'h0;
                        request_busy  <= 1'h0;
                        status        <= IDLE;
                    end
                    else begin
                        cnt <= cnt + 3'h1;
                    end
                end
                WR: begin
                    request_busy <= 1'h0;
                    status       <= IDLE;
                end
                default: status <= IDLE;
            endcase
        end
    end

endmodule
