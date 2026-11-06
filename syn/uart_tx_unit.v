`timescale 1ns / 1ns

module uart_tx_unit #(
    parameter DIV = 50_000_000 / 115_200
) (
    input              clk,
    input              rst_n,

    // 设备总线请求
    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [31:0]  request_addr,
    input      [127:0] request_data,

    // 设备总线响应
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data,

    // uart 物理引脚
    output reg         tx
);

// #region 请求缓存
reg push;
reg finish;
// 组合逻辑接口


reg [15:0]  p_be;
reg [127:0] p_data;

reg       byte_valid;
reg [3:0] byte_index;

always @(*) begin : ind
    integer i;
    byte_valid = 1'h0;
    byte_index = 4'h0;
    for (i = 15; i >= 0; i = i - 1) begin
        if (p_be[i]) begin
            byte_valid = 1'h1;
            byte_index = i[3:0];
        end
    end
end

always @(posedge clk) begin
    if (push) begin
        p_be <= request_be;
        p_data <= request_data;
    end
    else if (finish) begin
        p_be[byte_index] <= 1'h0;
    end
end
// #endregion



// #region 状态机
reg [2:0] nxt_status;


localparam IDLE  = 3'h0;
localparam READ  = 3'h1;
localparam SEND0 = 3'h2;
localparam SEND1 = 3'h3;
localparam SEND2 = 3'h4;
reg [2:0] status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= IDLE;
    end
    else begin
        status <= nxt_status;
    end
end
// #endregion



// #region 计时器
reg        t0_set;
reg        t0_dec;
reg        t1_set;

reg [2:0]  t0;
reg [31:0] t1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        t0 <= 3'h0;
        t1 <= 32'h1;
    end
    else begin
        if (t0_set) begin
            t0 <= 3'h7;
        end
        else if (t0_dec) begin
            t0 <= t0 - 3'h1;
        end
        if (t1_set) begin
            t1 <= DIV - 32'h1;
        end
        else if (t1 != 32'h0) begin
            t1 <= t1 - 32'h1;
        end
    end
end
// #endregion



// #region 响应缓存
reg        nxt_respond_valid;
reg [15:0] nxt_respond_data;
reg        set_tx;
reg        nxt_tx;
// 组合逻辑接口


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_valid <= 1'h0;
        tx <= 1'h1;
    end
    else begin
        respond_valid <= nxt_respond_valid;
        respond_data <= nxt_respond_data;
        if (set_tx) begin
            tx <= nxt_tx;
        end
    end
end
// #endregion



always @(*) begin : comb
    integer i;
    request_busy = 1'h1;
    push         = 1'h0;
    finish       = 1'h0;
    nxt_status   = IDLE;
    t0_set       = 1'h0;
    t0_dec       = 1'h0;
    t1_set       = 1'h0;
    nxt_respond_valid = 1'h0;
    nxt_respond_data  = 16'h0;
    set_tx            = 1'h0;
    nxt_tx            = 1'h0;

    case (status)
        IDLE: begin
            request_busy = 1'h0;
            if (request_valid) begin
                if (request_we) begin
                    push = 1'h1;
                    nxt_status = SEND0;
                end
                else begin
                    t0_set = 1'h1;
                    nxt_status = READ;
                end
            end
            else begin
                nxt_status = IDLE;
            end
        end
        READ: begin
            t0_dec = 1'h1;
            nxt_respond_valid = 1'h1;
            nxt_respond_data  = 16'h0;
            if (t0 == 3'h0) begin
                nxt_status = IDLE;
            end
            else begin
                nxt_status = READ;
            end
        end
        SEND0: begin
            if (t1 == 32'h0) begin
                if (byte_valid) begin
                    set_tx = 1'h1;
                    nxt_tx = 1'h0;
                    t0_set = 1'h1;
                    t1_set = 1'h1;
                    nxt_status = SEND1;
                end
                else begin
                    nxt_status = IDLE;
                end
            end
            else begin
                nxt_status = SEND0;
            end
        end
        SEND1: begin
            if (t1 == 32'h0) begin
                set_tx = 1'h1;
                nxt_tx = p_data[{byte_index, ~t0}];
                t0_dec = 1'h1;
                t1_set = 1'h1;
                if (t0 == 3'h0) begin
                    nxt_status = SEND2;
                end
                else begin
                    nxt_status = SEND1;
                end
            end
            else begin
                nxt_status = SEND1;
            end
        end
        SEND2: begin
            if (t1 == 32'h0) begin
                nxt_status = SEND0;
                set_tx = 1'h1;
                nxt_tx = 1'h1;
                t1_set = 1'h1;
                finish = 1'h1;
            end
            else begin
                nxt_status = SEND2;
            end
        end
        default: ;
    endcase
end

endmodule
