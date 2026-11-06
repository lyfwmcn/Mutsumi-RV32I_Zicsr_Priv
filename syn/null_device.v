`timescale 1ns / 1ns

module null_device (
    input              clk,
    input              rst_n,

    input              request_valid,
    input              request_we,
    input      [15:0]  request_be,
    input      [31:0]  request_addr,
    input      [127:0] request_data,
    output reg         request_busy,
    output reg         respond_valid,
    output reg [15:0]  respond_data
);

reg nxt_status;


localparam IDLE = 1'h0;
localparam SEND = 1'h1;
reg status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= IDLE;
    end
    else begin
        status <= nxt_status;
    end
end

reg t_begin;


reg [2:0] t;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        t <= 3'h0;
    end
    else begin
        if (t_begin) begin
            t <= 3'h7;
        end
        else if (t != 3'h0) begin
            t <= t - 3'h1;
        end
    end
end

always @(*) begin
    request_busy  = 1'h0;
    respond_valid = 1'h0;
    respond_data  = 16'h0;
    nxt_status    = IDLE;
    t_begin       = 1'h0;
    case (status)
        IDLE: begin
            request_busy = 1'h0;
            if (request_valid && !request_we) begin
                t_begin = 1'h1;
                nxt_status = SEND;
            end
            else begin
                nxt_status = IDLE;
            end
        end
        SEND: begin
            request_busy = 1'h1;
            respond_valid = 1'h1;
            respond_data = 16'h0;
            if (t == 3'h0) begin
                nxt_status = IDLE;
            end
            else begin
                nxt_status = SEND;
            end
        end
        default: ;
    endcase
end

endmodule
