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
    input         flush,
    input         request_valid_instr,
    input         respond_fault_instr,
    input         respond_valid_instr,
    input         stall,
    input  [31:0] request_addr_instr,
    input  [31:0] request_addr_instr_plus4,
    input  [31:0] respond_data_instr,
    output        empty,
    output        full,
    output        instr_fault,
    output [31:0] instr,
    output [31:0] pc,
    output [31:0] pcplus4
);

// 尚未收到响应的请求
reg [31:0] pending_requests [7:0];
reg [31:0] pending_requests_plus4 [7:0];
reg [3:0]  pending_requests_read_pos;
reg [3:0]  pending_requests_write_pos;
wire [3:0] pending_requests_count;
// 挂起请求总量
assign pending_requests_count = pending_requests_write_pos - pending_requests_read_pos;

// 需要丢弃的挂起响应：flush 进入丢弃态并记录写指针快照，
// 读指针追上快照即退出丢弃态。
reg [3:0] trash_until_pos;
reg       trash_active;
wire      trash_pending;
assign trash_pending = trash_active && (pending_requests_read_pos != trash_until_pos);

// 响应数据缓冲区
reg [31:0] pc_buffer [7:0];
reg [31:0] pcplus4_buffer [7:0];
reg        instr_fault_buffer [7:0];
reg [31:0] instr_buffer [7:0];
reg [3:0]  buffer_read_pos;
reg [3:0]  buffer_write_pos;
wire [3:0] buffer_count;
// 缓冲区响应数据总量
assign buffer_count = buffer_write_pos - buffer_read_pos;

// 写条件保证 buffer_count ∈ [0,8]：满 8 ⇔ 低 3 位相等且 bit3 相异
wire buffer_full8;
assign buffer_full8 = (buffer_write_pos[2:0] == buffer_read_pos[2:0]) &&
                      (buffer_write_pos[3]   != buffer_read_pos[3]);

integer i;
initial begin
    for (i = 0; i < 8; i = i + 1) begin
        pending_requests[i] = 32'h0;
    end
    for (i = 0; i < 8; i = i + 1) begin
        pending_requests_plus4[i] = 32'h0;
    end
    pending_requests_read_pos = 4'h0;
    pending_requests_write_pos = 4'h0;
    trash_until_pos = 4'h0;
    trash_active = 1'h0;
    for (i = 0; i < 8; i = i + 1) begin
        pc_buffer[i] = 32'h0;
    end
    for (i = 0; i < 8; i = i + 1) begin
        pcplus4_buffer[i] = 32'h0;
    end
    for (i = 0; i < 8; i = i + 1) begin
        instr_fault_buffer[i] = 1'h0;
    end
    for (i = 0; i < 8; i = i + 1) begin
        instr_buffer[i] = 32'h0;
    end
    buffer_read_pos = 4'h0;
    buffer_write_pos = 4'h0;
end

assign empty = buffer_write_pos == buffer_read_pos;
assign full = buffer_count + pending_requests_count >= 4'h8;
assign instr_fault = empty ? 1'h0 : instr_fault_buffer[buffer_read_pos[2:0]];
assign instr = empty ? 32'h13 : instr_buffer[buffer_read_pos[2:0]];
assign pc = empty ? 32'h0 : pc_buffer[buffer_read_pos[2:0]];
assign pcplus4 = empty ? 32'h0 : pcplus4_buffer[buffer_read_pos[2:0]];

// 是否完成/丢弃一个挂起请求
wire pending_requests_read;
// 是否写入一个挂起请求
wire pending_requests_write;
// 是否从缓冲区读出一个数据
wire buffer_read;
// 是否将响应数据写入缓冲区
wire buffer_write;
// 是否冲刷缓冲区
wire buffer_flush;

assign pending_requests_read = respond_valid_instr;
// 原式 (!buffer_write && (pr||br)) || (buffer_write && pr && br)
//   恒等化简为 (pr && !bw) || (br && (!bw || pr))
assign pending_requests_write = request_valid_instr && !flush &&
        (!full || (pending_requests_read && !buffer_write) ||
         (buffer_read && (!buffer_write || pending_requests_read)));
assign buffer_read = !empty && !stall;
assign buffer_write = respond_valid_instr && !trash_pending && !flush &&
        (!buffer_full8 || buffer_read);
assign buffer_flush = flush;

always @(posedge clk) begin
    if (pending_requests_write) begin
        pending_requests[pending_requests_write_pos[2:0]] <= request_addr_instr;
        pending_requests_plus4[pending_requests_write_pos[2:0]] <= request_addr_instr_plus4;
        pending_requests_write_pos <= pending_requests_write_pos + 4'h1;
    end
    if (pending_requests_read) begin
        pending_requests_read_pos <= pending_requests_read_pos + 4'h1;
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
            instr_buffer[buffer_write_pos[2:0]] <= respond_data_instr;
            pc_buffer[buffer_write_pos[2:0]] <= pending_requests[pending_requests_read_pos[2:0]];
            pcplus4_buffer[buffer_write_pos[2:0]] <= pending_requests_plus4[pending_requests_read_pos[2:0]];
            buffer_write_pos <= buffer_write_pos + 4'h1;
        end
        if (buffer_read) begin
            buffer_read_pos <= buffer_read_pos + 4'h1;
        end
    end
end

endmodule
