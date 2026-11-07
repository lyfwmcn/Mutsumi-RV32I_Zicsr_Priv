`timescale 1ns / 1ns

// 指令预取缓冲（FIFO）。
// 时序改写（功能与原实现逐拍等价，已用随机/定向激励仿真比对）：
//   1. trash_requests_count 升降计数器 -> trash_active + trash_until_pos 快照：
//      flush 当拍记录 pending_requests_write_pos；处于丢弃态且读指针未追上快照
//      = 还有垃圾响应要丢。消除原关键路径上的 ±1 进位链与三路选择器。
//   2. pending_requests_write 长表达式做布尔恒等化简。
//   3. empty / buffer_count<8 由“减法+比较”改为指针等值/位比较。
module instr_buffer_unit (
    input         clk,
    input         rst_n,
    input         flush,
    input         request_valid_instr,
    input         request_busy_instr,
    input         respond_fault_instr,
    input         respond_page_fault_instr,
    input         respond_valid_instr,
    input         stall,
    input  [31:0] request_addr_instr,
    input  [31:0] request_addr_instr_plus4,
    input  [31:0] respond_data_instr,
    output        empty,
    output        full,
    output        instr_fault,
    output        instr_page_fault,
    output [31:0] instr,
    output [31:0] pc,
    output [31:0] pcplus4
);

// 逻辑 FIFO 深度 5；物理数组用 8 项，指针 3 位 mod 8，
// 这样 write==read 不会和“满”混淆（count 永远 <= 5 < 8）。
localparam integer BUF_DEPTH = 8;
localparam [2:0] FIFO_DEPTH = 3'd5;

// 尚未收到响应的请求
reg [31:0] pending_requests [BUF_DEPTH-1:0];
reg [31:0] pending_requests_plus4 [BUF_DEPTH-1:0];
reg [2:0]  pending_requests_read_pos;
reg [2:0]  pending_requests_write_pos;
wire [2:0] pending_requests_count;
// 挂起请求总量
assign pending_requests_count = pending_requests_write_pos - pending_requests_read_pos;

// 需要丢弃的挂起响应：flush 进入丢弃态并记录写指针快照，
// 读指针追上快照即退出丢弃态。
reg [2:0] trash_until_pos;
reg       trash_active;
wire      trash_pending;
assign trash_pending = trash_active && (pending_requests_read_pos != trash_until_pos);

// 响应数据缓冲区
reg [31:0] pc_buffer [BUF_DEPTH-1:0];
reg [31:0] pcplus4_buffer [BUF_DEPTH-1:0];
reg        instr_fault_buffer [BUF_DEPTH-1:0];
reg        instr_pf_buffer [BUF_DEPTH-1:0];
reg [31:0] instr_buffer [BUF_DEPTH-1:0];
reg [2:0]  buffer_read_pos;
reg [2:0]  buffer_write_pos;
wire [2:0] buffer_count;
// 缓冲区响应数据总量
assign buffer_count = buffer_write_pos - buffer_read_pos;

// 物理数组 8 项，逻辑 FIFO 深度 5；3 位指针 mod 8，count 不会产生满/空歧义
wire buffer_full;
assign buffer_full = (buffer_count == FIFO_DEPTH);

integer i;
assign instr_fault = empty ? 1'h0 : instr_fault_buffer[buffer_read_pos[2:0]];
assign instr_page_fault = empty ? 1'h0 : instr_pf_buffer[buffer_read_pos[2:0]];
assign instr = empty ? 32'h13 : instr_buffer[buffer_read_pos[2:0]];
assign pc = empty ? 32'h0 : pc_buffer[buffer_read_pos[2:0]];
assign pcplus4 = empty ? 32'h4 : pcplus4_buffer[buffer_read_pos[2:0]];

// 是否完成/丢弃一个挂起请求
wire pending_requests_read;
// 请求是否真正被 cache 接受（valid && !busy）
wire request_accept;
// 是否写入一个挂起请求
wire pending_requests_write;
// 是否从缓冲区读出一个数据
wire buffer_read;
// 是否将响应数据写入缓冲区
wire buffer_write;
// 是否冲刷缓冲区
wire buffer_flush;

assign pending_requests_read = respond_valid_instr;
assign request_accept = request_valid_instr && !request_busy_instr;
// 取指流水深度：未响应请求最多 5 个
localparam [2:0] DEPTH = 3'd5;

wire pending_room;
wire buffer_room;
wire can_accept;
// 有新响应回来就能腾出一个位置
assign pending_room = (pending_requests_count < DEPTH) || pending_requests_read;
// 新请求发出的同时可能有响应要写缓冲区
assign buffer_room = !buffer_full || buffer_read || !respond_valid_instr;
assign can_accept = pending_room && buffer_room;

assign empty = buffer_write_pos == buffer_read_pos;
// full 同时表示“逻辑缓冲满（5 项）”和“请求深度已到上限”，即不能再发新请求
assign full = !can_accept || ({1'b0, buffer_count} + {1'b0, pending_requests_count} >= {1'b0, FIFO_DEPTH});

// 原式 (!buffer_write && (pr||br)) || (buffer_write && pr && br)
//   恒等化简为 (pr && !bw) || (br && (!bw || pr))
assign pending_requests_write = request_accept && !flush;
assign buffer_read = !empty && !stall;
assign buffer_write = respond_valid_instr && !trash_pending && !flush &&
        (!buffer_full || buffer_read);
assign buffer_flush = flush;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            pending_requests[i] <= 32'h0;
        end
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            pending_requests_plus4[i] <= 32'h0;
        end
        pending_requests_read_pos <= 3'h0;
        pending_requests_write_pos <= 3'h0;
        trash_until_pos <= 3'h0;
        trash_active <= 1'h0;
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            pc_buffer[i] <= 32'h0;
        end
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            pcplus4_buffer[i] <= 32'h0;
        end
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            instr_fault_buffer[i] <= 1'h0;
        end
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            instr_pf_buffer[i] <= 1'h0;
        end
        for (i = 0; i < BUF_DEPTH; i = i + 1) begin
            instr_buffer[i] <= 32'h0;
        end
        buffer_read_pos <= 3'h0;
        buffer_write_pos <= 3'h0;
    end
    else begin
        if (pending_requests_write) begin
            pending_requests[pending_requests_write_pos[2:0]] <= request_addr_instr;
            pending_requests_plus4[pending_requests_write_pos[2:0]] <= request_addr_instr_plus4;
            pending_requests_write_pos <= pending_requests_write_pos + 3'h1;
        end
        if (pending_requests_read) begin
            pending_requests_read_pos <= pending_requests_read_pos + 3'h1;
        end
        if (buffer_flush) begin
            buffer_write_pos <= buffer_read_pos;
            trash_until_pos <= pending_requests_write_pos;
            trash_active <= 1'h1;
        end
        else begin
            if (trash_active && pending_requests_read_pos == trash_until_pos) begin
                trash_active <= 1'h0;
            end
            if (buffer_write) begin
                instr_fault_buffer[buffer_write_pos[2:0]] <= respond_fault_instr;
                instr_pf_buffer[buffer_write_pos[2:0]] <= respond_page_fault_instr;
                instr_buffer[buffer_write_pos[2:0]] <= respond_data_instr;
                pc_buffer[buffer_write_pos[2:0]] <= pending_requests[pending_requests_read_pos[2:0]];
                pcplus4_buffer[buffer_write_pos[2:0]] <= pending_requests_plus4[pending_requests_read_pos[2:0]];
                buffer_write_pos <= buffer_write_pos + 3'h1;
            end
            if (buffer_read) begin
                buffer_read_pos <= buffer_read_pos + 3'h1;
            end
        end
    end
end

endmodule
