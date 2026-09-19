`timescale 1ns / 1ns

// 6.7 ns
module id_stage (
    // 全局参数
    input             clk,
    input             flush,
    input             stall,
    input      [1:0]  privilege,

    // 旁路参数
    output            predtaken,
    output     [31:0] id_jump_addr,

    // 流水线参数
    input             id_instr_access_fault,
    input             id_instr_page_fault,
    input             id_is_instr,
    input      [31:0] id_instr,
    input      [31:0] id_pc,
    input      [31:0] id_pcplus4,
    output reg        ex1_alu_src_a,
    output reg        ex1_csr_wr,
    output reg        ex1_data_ren,
    output reg        ex1_data_wen,
    output reg        ex1_ebreak,
    output reg        ex1_ecall,
    output reg        ex1_instr_access_fault,
    output reg        ex1_instr_illegal_fault,
    output reg        ex1_instr_page_fault,
    output reg        ex1_is_csr,
    output reg        ex1_is_instr,
    output reg        ex1_predtaken,
    output reg        ex1_reg_out_a_used,
    output reg        ex1_reg_out_b_used,
    output reg        ex1_reg_wr,
    output reg        ex1_ret,
    output reg        ex1_ret_type,
    output reg [1:0]  ex1_alu_src_b,
    output reg [1:0]  ex1_csr_src,
    output reg [2:0]  ex1_mem_ctr,
    output reg [2:0]  ex1_reg_src,
    output reg [4:0]  ex1_branch_ctr,
    output reg [4:0]  ex1_rd,
    output reg [4:0]  ex1_rs1,
    output reg [4:0]  ex1_rs2,
    output reg [5:0]  ex1_alu_ctr,
    output reg [11:0] ex1_csr_rd,
    output reg [31:0] ex1_imm,
    output reg [31:0] ex1_instr,
    output reg [31:0] ex1_pc,
    output reg [31:0] ex1_pcplus4,
    output reg [31:0] ex1_pcplusimm
);


wire id_predtaken;
wire id_reg_out_a_used;
wire id_reg_out_b_used;
wire id_csr_wr;
wire id_data_ren;
wire id_data_wen;
wire id_ebreak;
wire id_ecall;
wire id_instr_illegal_fault;
wire id_is_csr;
wire id_reg_wr;
wire id_ret;
wire id_ret_type;
wire id_alu_src_a;
wire [1:0] id_alu_src_b;
wire [1:0] id_csr_src;
wire [2:0] id_mem_ctr;
wire [2:0] id_reg_src;
wire [4:0] id_branch_ctr;
wire [4:0] id_rd;
wire [4:0] id_rs1;
wire [4:0] id_rs2;
wire [5:0] id_alu_ctr;
wire [11:0] id_csr_rd;
wire [31:0] id_imm;
wire [31:0] id_pcplusimm;

initial begin
    ex1_alu_src_a = 1'h0;
    ex1_csr_wr = 1'h0;
    ex1_data_ren = 1'h0;
    ex1_data_wen = 1'h0;
    ex1_ebreak = 1'h0;
    ex1_ecall = 1'h0;
    ex1_instr_access_fault = 1'h0;
    ex1_instr_illegal_fault = 1'h0;
    ex1_instr_page_fault = 1'h0;
    ex1_is_csr = 1'h0;
    ex1_is_instr = 1'h0;
    ex1_predtaken = 1'h0;
    ex1_reg_out_a_used = 1'h0;
    ex1_reg_out_b_used = 1'h0;
    ex1_reg_wr = 1'h0;
    ex1_ret = 1'h0;
    ex1_ret_type = 1'h0;
    ex1_alu_src_b = 2'h0;
    ex1_csr_src = 2'h0;
    ex1_mem_ctr = 3'h0;
    ex1_reg_src = 3'h0;
    ex1_branch_ctr = 5'h0;
    ex1_rd = 5'h0;
    ex1_rs1 = 5'h0;
    ex1_rs2 = 5'h0;
    ex1_alu_ctr = 6'h0;
    ex1_csr_rd = 12'h0;
    ex1_imm = 32'h0;
    ex1_instr = 32'h0;
    ex1_pc = 32'h0;
    ex1_pcplus4 = 32'h0;
    ex1_pcplusimm = 32'h0;
end

always @(posedge clk) begin
    if (flush) begin
        ex1_alu_src_a <= 1'h0;
        ex1_csr_wr <= 1'h0;
        ex1_data_ren <= 1'h0;
        ex1_data_wen <= 1'h0;
        ex1_ebreak <= 1'h0;
        ex1_ecall <= 1'h0;
        ex1_instr_access_fault <= 1'h0;
        ex1_instr_illegal_fault <= 1'h0;
        ex1_instr_page_fault <= 1'h0;
        ex1_is_csr <= 1'h0;
        ex1_is_instr <= 1'h0;
        ex1_predtaken <= 1'h0;
        ex1_reg_out_a_used <= 1'h0;
        ex1_reg_out_b_used <= 1'h0;
        ex1_reg_wr <= 1'h0;
        ex1_ret <= 1'h0;
        ex1_ret_type <= 1'h0;
        ex1_alu_src_b <= 2'h0;
        ex1_csr_src <= 2'h0;
        ex1_mem_ctr <= 3'h0;
        ex1_reg_src <= 3'h0;
        ex1_branch_ctr <= 5'h0;
        ex1_rd <= 5'h0;
        ex1_rs1 <= 5'h0;
        ex1_rs2 <= 5'h0;
        ex1_alu_ctr <= 6'h0;
        ex1_csr_rd <= 12'h0;
        ex1_imm <= 32'h0;
        ex1_instr <= 32'h0;
        ex1_pc <= 32'h0;
        ex1_pcplus4 <= 32'h0;
        ex1_pcplusimm <= 32'h0;
    end
    else if (!stall) begin
        ex1_alu_src_a <= id_alu_src_a;
        ex1_csr_wr <= id_csr_wr;
        ex1_data_ren <= id_data_ren;
        ex1_data_wen <= id_data_wen;
        ex1_ebreak <= id_ebreak;
        ex1_ecall <= id_ecall;
        ex1_instr_access_fault <= id_instr_access_fault;
        ex1_instr_illegal_fault <= id_instr_illegal_fault;
        ex1_instr_page_fault <= id_instr_page_fault;
        ex1_is_csr <= id_is_csr;
        ex1_is_instr <= id_is_instr;
        ex1_predtaken <= id_predtaken;
        ex1_reg_out_a_used <= id_reg_out_a_used;
        ex1_reg_out_b_used <= id_reg_out_b_used;
        ex1_reg_wr <= id_reg_wr;
        ex1_ret <= id_ret;
        ex1_ret_type <= id_ret_type;
        ex1_alu_src_b <= id_alu_src_b;
        ex1_csr_src <= id_csr_src;
        ex1_mem_ctr <= id_mem_ctr;
        ex1_reg_src <= id_reg_src;
        ex1_branch_ctr <= id_branch_ctr;
        ex1_rd <= id_rd;
        ex1_rs1 <= id_rs1;
        ex1_rs2 <= id_rs2;
        ex1_alu_ctr <= id_alu_ctr;
        ex1_csr_rd <= id_csr_rd;
        ex1_imm <= id_imm;
        ex1_instr <= id_instr;
        ex1_pc <= id_pc;
        ex1_pcplus4 <= id_pcplus4;
        ex1_pcplusimm <= id_pcplusimm;
    end
end

assign predtaken = id_predtaken && id_jump_addr[1:0] == 2'h0;

idu idu (
    .privilege          (privilege),
    .instr              (id_instr),
    .alu_src_a          (id_alu_src_a),
    .csr_wr             (id_csr_wr),
    .data_ren           (id_data_ren),
    .data_wen           (id_data_wen),
    .ebreak             (id_ebreak),
    .ecall              (id_ecall),
    .instr_illegal_fault(id_instr_illegal_fault),
    .is_csr             (id_is_csr),
    .predtaken          (id_predtaken),
    .reg_out_a_used     (id_reg_out_a_used),
    .reg_out_b_used     (id_reg_out_b_used),
    .reg_wr             (id_reg_wr),
    .ret                (id_ret),
    .ret_type           (id_ret_type),
    .alu_src_b          (id_alu_src_b),
    .csr_src            (id_csr_src),
    .mem_ctr            (id_mem_ctr),
    .reg_src            (id_reg_src),
    .branch_ctr         (id_branch_ctr),
    .rd                 (id_rd),
    .rs1                (id_rs1),
    .rs2                (id_rs2),
    .alu_ctr            (id_alu_ctr),
    .csr_rd             (id_csr_rd),
    .imm                (id_imm)
);

assign id_jump_addr = id_pcplusimm;
// auipc, B, J 指令专用
assign id_pcplusimm = id_pc +
                      (id_instr[4] ? {id_instr[31:12], 12'h0} : id_instr[2] ?
                      {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'h0} :
                      {{19{id_instr[31]}}, id_instr[31], id_instr[7], id_instr[30:25], id_instr[11:8], 1'h0});

endmodule
