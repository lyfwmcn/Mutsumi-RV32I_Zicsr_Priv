`timescale 1ns / 1ns

module boot_rom (
    input              clk,
    input              rst_n,

    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [10:0]  request_addr,
    input      [127:0] request_data,
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data
);



// #region ROM
reg         re;
reg [7:0]   addr;
reg [127:0] line_out;
// 组合逻辑接口


(* ram_style = "block" *)
reg [127:0] mem [255:0];

initial begin
    $readmemh("build/boot.hex", mem);
end

always @(posedge clk) begin
    if (re) begin
        line_out <= mem[addr];
    end
end
// #endregion



// #region 请求缓存
reg push;
// 组合逻辑接口


reg [10:0] p_request_addr;

always @(posedge clk) begin
    if (push) begin
        p_request_addr <= request_addr;
    end
end
// #endregion



// #region 计时器
reg t_begin;
// 组合逻辑接口


reg [2:0] t;
always @(posedge clk) begin
    if (t_begin) begin
        t <= 3'h0;
    end
    else if (t != 3'h7) begin
        t <= t + 3'h1;
    end
end
// #endregion



// #region 状态机
reg [1:0] nxt_status;

localparam IDLE = 2'h0;
localparam READ = 2'h1;
localparam RUN  = 2'h2;
reg [1:0] status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= IDLE;
    end
    else begin
        status <= nxt_status;
    end
end
// #endregion



// #region 响应缓存
reg        nxt_respond_valid;
reg [15:0] nxt_respond_data;
// 组合逻辑接口


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_valid <= 1'h0;
    end
    else begin
        respond_valid <= nxt_respond_valid;
        respond_data  <= nxt_respond_data;
    end
end
// #endregion



always @(*) begin
    request_busy = 1'h1;
    re = 1'h0;
    addr = 8'h0;
    push = 1'h0;
    t_begin = 1'h0;
    nxt_status = IDLE;
    nxt_respond_valid = 1'h0;
    nxt_respond_data = 16'h0;
    case (status)
        IDLE: begin
            request_busy = 1'h0;
            if (request_valid && !request_we) begin
                nxt_status = READ;
                push = 1'h1;
            end
            else begin
                nxt_status = IDLE;
            end
        end
        READ: begin
            nxt_status = RUN;
            t_begin = 1'h1;
            re = 1'h1;
            addr = p_request_addr[10:3];
        end
        RUN: begin
            nxt_respond_valid = 1'h1;
            nxt_respond_data = line_out[{p_request_addr[2:0] + t, 4'h0} +: 16];
            if (t == 3'h7) begin
                nxt_status = IDLE;
            end
            else begin
                nxt_status = RUN;
            end
        end
        default: ;
    endcase
end

endmodule
