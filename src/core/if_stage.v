`timescale 1ns / 1ns

module if_stage (
    // 全局参数
    input         clk,
    input         rst_n,
    input         flush,
    input         stall,
    input         actual_jump,
    // 冲刷后重新从 redirect_pc 取指（satp 写入时用）
    input         redirect,
    input  [31:0] redirect_pc,
    input         predtaken,
    input         ret,
    input         ret_type,
    input         trap,
    input         trap_type,
    input  [31:0] mepc,
    input  [31:0] mtvec,
    input  [31:0] sepc,
    input  [31:0] stvec,

    // 外部通信参数
    input         respond_fault_instr,
    input         respond_page_fault_instr,
    input         respond_valid_instr,
    input  [31:0] respond_data_instr,
    input         request_busy_instr,
    output        request_valid_instr,
    output [29:0] request_addr_instr,

    // 旁路参数
    input  [31:0] id_jump_addr,
    input  [31:0] m2_jump_addr,

    // 流水线参数
    output        id_instr_access_fault,
    output        id_instr_page_fault,
    output        id_is_instr,
    output [31:0] id_instr,
    output [31:0] id_pc,
    output [31:0] id_pcplus4
);

wire full;
wire empty;
assign request_valid_instr = !stall && !flush && !full && !request_busy_instr;

// 握手：valid && !busy 才算请求被 cache 接受。
// pc 在"被接受"的同一拍就前进（组合），这样取指可以连续发请求（预取能堆到 2 笔）。
// 注意：这会把 cache 的 busy 组合路径接到 pc 的时钟使能上，是吞吐换时序的取舍。
wire pc_hold;
assign pc_hold = !request_valid_instr;

assign id_is_instr = !empty && !id_instr_access_fault && !id_instr_page_fault;

wire [31:0] pc;
wire [31:0] pcplus4;
assign request_addr_instr = pc[31:2];

pc_reg pc_reg (
    .clk         (clk),
    .rst_n       (rst_n),
    .actual_jump (actual_jump),
    .redirect    (redirect),
    .redirect_pc (redirect_pc),
    .stall       (stall),
    .hold        (pc_hold),
    .ret         (ret),
    .ret_type    (ret_type),
    .trap        (trap),
    .trap_type   (trap_type),
    .predtaken   (predtaken),
    .id_jump_addr(id_jump_addr),
    .m2_jump_addr(m2_jump_addr),
    .mepc        (mepc),
    .mtvec       (mtvec),
    .sepc        (sepc),
    .stvec       (stvec),
    .pc          (pc),
    .pcplus4     (pcplus4)
);

instr_buffer_unit instr_buffer_unit (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .flush                   (flush),
    .request_valid_instr     (request_valid_instr),
    .request_busy_instr      (request_busy_instr),
    .respond_fault_instr     (respond_fault_instr),
    .respond_page_fault_instr(respond_page_fault_instr),
    .respond_valid_instr     (respond_valid_instr),
    .stall                   (stall),
    .request_addr_instr      (pc),
    .request_addr_instr_plus4(pcplus4),
    .respond_data_instr      (respond_data_instr),
    .empty                   (empty),
    .full                    (full),
    .instr_fault             (id_instr_access_fault),
    .instr_page_fault        (id_instr_page_fault),
    .instr                   (id_instr),
    .pc                      (id_pc),
    .pcplus4                 (id_pcplus4)
);

endmodule
