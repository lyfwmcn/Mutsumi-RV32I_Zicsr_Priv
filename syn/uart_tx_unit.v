`timescale 1ns / 1ns

// UART 发送单元（设备总线从机，接口与 boot_rom / sdram_ctr / null_device 一致）
//
// 行为：
//   - 读（request_we = 0）：连续 8 拍返回 0（respond_valid 高 8 拍，respond_data = 16'h0000）
//   - 写（request_we = 1）：在 request_be[15:0] 里找**第一个**（下标最小的）为 1 的字节，
//                          取 request_data 里对应的那个字节，用 8N1（起始位 0 + 8 位数据 + 停止位 1）
//                          从 tx 发出去；先发 LSB
//   - request_busy 在整段操作期间保持 1：读 8 拍 / 写的 10 个位时间
//   - 写没有响应（与 sdram 控制器的写口一致）；be == 0 时不发送，直接结束
//
// 注：原接口里的 valid / data 输入输出同名，无法同时存在，故用 request_* / respond_* 前缀区分。
module uart_tx_unit #(
    parameter DIV = 50_000_000 / 115_200
) (
    input         clk,
    input         rst_n,

    // 设备总线请求
    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [127:0] request_data,

    // 设备总线响应
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data,

    // uart 物理引脚
    output             tx
);

localparam IDLE = 2'h0;
localparam RD   = 2'h1; // 读：连续 8 拍返回 0
localparam SEND = 2'h2; // 写：把选中的字节串出去

reg [1:0]  state;
reg [31:0] clk_cnt;
reg [3:0]  tx_idx;
reg [9:0]  tx_buf;
reg [2:0]  rd_cnt;

// 从 16 字节里找第一个 be = 1 的字节（be[0] 优先级最高）
integer i;
reg [3:0] byte_idx;
reg       byte_found;
reg [7:0] byte_sel;
always @(*) begin
    byte_idx   = 4'h0;
    byte_found = 1'h0;
    for (i = 15; i >= 0; i = i - 1) begin
        if (request_be[i]) begin
            byte_idx   = i[3:0]; // 从高往低扫，最后赋值 = 下标最小的 1
            byte_found = 1'h1;
        end
    end
end

// 显式的 16:1 字节选择（写成 case 而不是变量部分选择，否则会被综合成桶形移位器）
always @(*) begin
    case (byte_idx)
        4'd0:    byte_sel = request_data[7:0];
        4'd1:    byte_sel = request_data[15:8];
        4'd2:    byte_sel = request_data[23:16];
        4'd3:    byte_sel = request_data[31:24];
        4'd4:    byte_sel = request_data[39:32];
        4'd5:    byte_sel = request_data[47:40];
        4'd6:    byte_sel = request_data[55:48];
        4'd7:    byte_sel = request_data[63:56];
        4'd8:    byte_sel = request_data[71:64];
        4'd9:    byte_sel = request_data[79:72];
        4'd10:   byte_sel = request_data[87:80];
        4'd11:   byte_sel = request_data[95:88];
        4'd12:   byte_sel = request_data[103:96];
        4'd13:   byte_sel = request_data[111:104];
        4'd14:   byte_sel = request_data[119:112];
        default: byte_sel = request_data[127:120];
    endcase
end

always @(*) begin
    request_busy = (state != IDLE);
    respond_valid = (state == RD);
    respond_data  = 16'h0000;
end
assign tx = tx_buf[tx_idx];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= IDLE;
        clk_cnt <= 32'h0;
        tx_idx  <= 4'h0;
        tx_buf  <= 10'h3ff;
        rd_cnt  <= 3'h0;
    end
    else begin
        case (state)
            IDLE: begin
                clk_cnt <= 32'h0;
                tx_idx  <= 4'h0;
                rd_cnt  <= 3'h0;
                if (request_valid) begin
                    if (request_we) begin
                        if (byte_found) begin
                            state  <= SEND;
                            tx_buf <= {1'b1, byte_sel, 1'b0}; // 停止位 + 数据 + 起始位
                        end
                        // be == 0：没有要发的字节，直接结束（request_busy 只在这一拍为 1）
                    end
                    else begin
                        state <= RD;
                    end
                end
            end

            // 读：连续 8 拍返回 0（对应一次 BL=8 读突发）
            RD: begin
                if (rd_cnt == 3'h7) begin
                    state <= IDLE;
                end
                else begin
                    rd_cnt <= rd_cnt + 3'h1;
                end
            end

            // 写：10 个位时间把 tx_buf 逐位移出
            SEND: begin
                if (clk_cnt == DIV - 1) begin
                    clk_cnt <= 32'h0;
                    if (tx_idx == 4'h9) begin
                        state  <= IDLE;
                        tx_idx <= 4'h0;
                        tx_buf <= 10'h3ff;
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
