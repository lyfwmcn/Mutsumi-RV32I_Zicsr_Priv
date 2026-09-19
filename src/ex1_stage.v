`timescale 1ns / 1ns

// 8.2 ns
module ex1_stage (
    // 全局参数
    input             clk,
    input             flush,
    input             stall,
    output            csr_wait,
    output            reg_wait,

    // 旁路参数
    input             m1_csr_wr,
    input             m1_is_csr,
    input             m1_reg_wr,
    input             m2_csr_wr,
    input             m2_is_csr,
    input             m2_reg_wr,
    input             wb_csr_wr,
    input             wb_is_csr,
    input             wb_reg_wr,
    input      [2:0]  m1_reg_src,
    input      [2:0]  m2_reg_src,
    input      [4:0]  m1_rd,
    input      [4:0]  m2_rd,
    input      [4:0]  wb_rd,
    input      [11:0] m1_csr_rd,
    input      [11:0] m2_csr_rd,
    input      [11:0] wb_csr_rd,
    input      [31:0] ex1_csr_out,
    input      [31:0] ex1_reg_out_a,
    input      [31:0] ex1_reg_out_b,
    input      [31:0] m1_raw_reg_in,
    input      [31:0] m2_raw_reg_in,
    input      [31:0] wb_reg_in,


    // 流水线参数
    input             ex1_alu_src_a,
    input             ex1_csr_wr,
    input             ex1_data_ren,
    input             ex1_data_wen,
    input             ex1_ebreak,
    input             ex1_ecall,
    input             ex1_instr_access_fault,
    input             ex1_instr_illegal_fault,
    input             ex1_instr_page_fault,
    input             ex1_is_csr,
    input             ex1_is_instr,
    input             ex1_predtaken,
    input             ex1_reg_out_a_used,
    input             ex1_reg_out_b_used,
    input             ex1_reg_wr,
    input             ex1_ret,
    input             ex1_ret_type,
    input      [1:0]  ex1_alu_src_b,
    input      [1:0]  ex1_csr_src,
    input      [2:0]  ex1_mem_ctr,
    input      [2:0]  ex1_reg_src,
    input      [4:0]  ex1_branch_ctr,
    input      [4:0]  ex1_rd,
    input      [4:0]  ex1_rs1,
    input      [4:0]  ex1_rs2,
    input      [5:0]  ex1_alu_ctr,
    input      [11:0] ex1_csr_rd,
    input      [31:0] ex1_imm,
    input      [31:0] ex1_instr,
    input      [31:0] ex1_pc,
    input      [31:0] ex1_pcplus4,
    input      [31:0] ex1_pcplusimm,
    output reg        ex2_aluinausem1,
    output reg        ex2_aluinbusem1,
    output reg        ex2_csr_wr,
    output reg        ex2_data_ren,
    output reg        ex2_data_wen,
    output reg        ex2_ebreak,
    output reg        ex2_ecall,
    output reg        ex2_instr_access_fault,
    output reg        ex2_instr_illegal_fault,
    output reg        ex2_instr_page_fault,
    output reg        ex2_is_csr,
    output reg        ex2_is_instr,
    output reg        ex2_predtaken,
    output reg        ex2_reg_wr,
    output reg        ex2_ret,
    output reg        ex2_ret_type,
    output reg        ex2_rs1usem1,
    output reg        ex2_rs2usem1,
    output reg [1:0]  ex2_csr_src,
    output reg [2:0]  ex2_mem_ctr,
    output reg [2:0]  ex2_reg_src,
    output reg [4:0]  ex2_branch_ctr,
    output reg [4:0]  ex2_rd,
    output reg [5:0]  ex2_alu_ctr,
    output reg [11:0] ex2_csr_rd,
    output reg [31:0] ex2_alu_in_a,
    output reg [31:0] ex2_alu_in_b,
    output reg [31:0] ex2_csr_out,
    output reg [31:0] ex2_imm,
    output reg [31:0] ex2_instr,
    output reg [31:0] ex2_pc,
    output reg [31:0] ex2_pcplus4,
    output reg [31:0] ex2_pcplusimm,
    output reg [31:0] ex2_reg_out_a,
    output reg [31:0] ex2_reg_out_b
);

wire ex1_aluinausem1;
wire ex1_aluinbusem1;
wire ex1_rs1usem1;
wire ex1_rs2usem1;
wire [31:0] ex1_reg_out_a_true;
wire [31:0] ex1_reg_out_b_true;
wire [31:0] ex1_alu_in_a;
wire [31:0] ex1_alu_in_b;

initial begin
    ex2_aluinausem1 = 1'h0;
    ex2_aluinbusem1 = 1'h0;
    ex2_csr_wr = 1'h0;
    ex2_data_ren = 1'h0;
    ex2_data_wen = 1'h0;
    ex2_ebreak = 1'h0;
    ex2_ecall = 1'h0;
    ex2_instr_access_fault = 1'h0;
    ex2_instr_illegal_fault = 1'h0;
    ex2_instr_page_fault = 1'h0;
    ex2_is_csr = 1'h0;
    ex2_is_instr = 1'h0;
    ex2_predtaken = 1'h0;
    ex2_reg_wr = 1'h1;
    ex2_ret = 1'h0;
    ex2_ret_type = 1'h0;
    ex2_rs1usem1 = 1'h0;
    ex2_rs2usem1 = 1'h0;
    ex2_csr_src = 2'h0;
    ex2_mem_ctr = 3'h0;
    ex2_reg_src = 3'h0;
    ex2_branch_ctr = 5'h0;
    ex2_rd = 5'h0;
    ex2_alu_ctr = 6'h0;
    ex2_csr_rd = 12'h0;
    ex2_alu_in_a = 32'h0;
    ex2_alu_in_b = 32'h0;
    ex2_csr_out = 32'h0;
    ex2_imm = 32'h0;
    ex2_instr = 32'h13;
    ex2_pc = 32'h0;
    ex2_pcplus4 = 32'h4;
    ex2_pcplusimm = 32'h0;
    ex2_reg_out_a = 32'h0;
    ex2_reg_out_b = 32'h0;
end

always @(posedge clk) begin
    if (flush) begin
        ex2_aluinausem1 <= 1'h0;
        ex2_aluinbusem1 <= 1'h0;
        ex2_csr_wr <= 1'h0;
        ex2_data_ren <= 1'h0;
        ex2_data_wen <= 1'h0;
        ex2_ebreak <= 1'h0;
        ex2_ecall <= 1'h0;
        ex2_instr_access_fault <= 1'h0;
        ex2_instr_illegal_fault <= 1'h0;
        ex2_instr_page_fault <= 1'h0;
        ex2_is_csr <= 1'h0;
        ex2_is_instr <= 1'h0;
        ex2_predtaken <= 1'h0;
        ex2_reg_wr <= 1'h1;
        ex2_ret <= 1'h0;
        ex2_ret_type <= 1'h0;
        ex2_rs1usem1 <= 1'h0;
        ex2_rs2usem1 <= 1'h0;
        ex2_csr_src <= 2'h0;
        ex2_mem_ctr <= 3'h0;
        ex2_reg_src <= 3'h0;
        ex2_branch_ctr <= 5'h0;
        ex2_rd <= 5'h0;
        ex2_alu_ctr <= 6'h0;
        ex2_csr_rd <= 12'h0;
        ex2_alu_in_a <= 32'h0;
        ex2_alu_in_b <= 32'h0;
        ex2_csr_out <= 32'h0;
        ex2_imm <= 32'h0;
        ex2_instr <= 32'h13;
        ex2_pc <= 32'h0;
        ex2_pcplus4 <= 32'h4;
        ex2_pcplusimm <= 32'h0;
        ex2_reg_out_a <= 32'h0;
        ex2_reg_out_b <= 32'h0;
    end
    else if (!stall) begin
        ex2_aluinausem1 <= ex1_aluinausem1;
        ex2_aluinbusem1 <= ex1_aluinbusem1;
        ex2_csr_wr <= ex1_csr_wr;
        ex2_data_ren <= ex1_data_ren;
        ex2_data_wen <= ex1_data_wen;
        ex2_ebreak <= ex1_ebreak;
        ex2_ecall <= ex1_ecall;
        ex2_instr_access_fault <= ex1_instr_access_fault;
        ex2_instr_illegal_fault <= ex1_instr_illegal_fault;
        ex2_instr_page_fault <= ex1_instr_page_fault;
        ex2_is_csr <= ex1_is_csr;
        ex2_is_instr <= ex1_is_instr;
        ex2_predtaken <= ex1_predtaken;
        ex2_reg_wr <= ex1_reg_wr;
        ex2_ret <= ex1_ret;
        ex2_ret_type <= ex1_ret_type;
        ex2_rs1usem1 <= ex1_rs1usem1;
        ex2_rs2usem1 <= ex1_rs2usem1;
        ex2_csr_src <= ex1_csr_src;
        ex2_mem_ctr <= ex1_mem_ctr;
        ex2_reg_src <= ex1_reg_src;
        ex2_branch_ctr <= ex1_branch_ctr;
        ex2_rd <= ex1_rd;
        ex2_alu_ctr <= ex1_alu_ctr;
        ex2_csr_rd <= ex1_csr_rd;
        ex2_alu_in_a <= ex1_alu_in_a;
        ex2_alu_in_b <= ex1_alu_in_b;
        ex2_csr_out <= ex1_csr_out;
        ex2_imm <= ex1_imm;
        ex2_instr <= ex1_instr;
        ex2_pc <= ex1_pc;
        ex2_pcplus4 <= ex1_pcplus4;
        ex2_pcplusimm <= ex1_pcplusimm;
        ex2_reg_out_a <= ex1_reg_out_a_true;
        ex2_reg_out_b <= ex1_reg_out_b_true;
    end
end

assign ex1_alu_in_a = ex1_alu_src_a == 1'h0 ? ex1_reg_out_a_true : ex1_imm;
assign ex1_alu_in_b = ex1_alu_src_b == 2'h0 ? ex1_reg_out_b_true :
                      ex1_alu_src_b == 2'h1 ? ex1_imm :
                      ex1_alu_src_b == 2'h2 ? ex1_csr_out :
                      32'h0;

reg_bypass reg_bypass (
    .ex1_alu_src_a     (ex1_alu_src_a),
    .ex1_reg_out_a_used(ex1_reg_out_a_used),
    .ex1_reg_out_b_used(ex1_reg_out_b_used),
    .ex2_reg_wr        (ex2_reg_wr),
    .m1_reg_wr         (m1_reg_wr),
    .m2_reg_wr         (m2_reg_wr),
    .wb_reg_wr         (wb_reg_wr),
    .ex1_alu_src_b     (ex1_alu_src_b),
    .ex2_reg_src       (ex2_reg_src),
    .m1_reg_src        (m1_reg_src),
    .m2_reg_src        (m2_reg_src),
    .ex1_rs1           (ex1_rs1),
    .ex1_rs2           (ex1_rs2),
    .ex2_rd            (ex2_rd),
    .m1_rd             (m1_rd),
    .m2_rd             (m2_rd),
    .wb_rd             (wb_rd),
    .ex1_reg_out_a     (ex1_reg_out_a),
    .ex1_reg_out_b     (ex1_reg_out_b),
    .m1_raw_reg_in     (m1_raw_reg_in),
    .m2_raw_reg_in     (m2_raw_reg_in),
    .wb_reg_in         (wb_reg_in),
    .reg_wait          (reg_wait),
    .ex1_rs1usem1      (ex1_rs1usem1),
    .ex1_rs2usem1      (ex1_rs2usem1),
    .ex1_aluinausem1   (ex1_aluinausem1),
    .ex1_aluinbusem1   (ex1_aluinbusem1),
    .ex1_reg_out_a_true(ex1_reg_out_a_true),
    .ex1_reg_out_b_true(ex1_reg_out_b_true)
);

csr_hazard csr_hazard (
    .ex1_is_csr(ex1_is_csr),
    .ex2_csr_wr(ex2_csr_wr),
    .ex2_is_csr(ex2_is_csr),
    .m1_csr_wr (m1_csr_wr),
    .m1_is_csr (m1_is_csr),
    .m2_csr_wr (m2_csr_wr),
    .m2_is_csr (m2_is_csr),
    .wb_csr_wr (wb_csr_wr),
    .wb_is_csr (wb_is_csr),
    .ex1_csr_rd(ex1_csr_rd),
    .ex2_csr_rd(ex2_csr_rd),
    .m1_csr_rd (m1_csr_rd),
    .m2_csr_rd (m2_csr_rd),
    .wb_csr_rd (wb_csr_rd),
    .csr_wait  (csr_wait)
);

endmodule
