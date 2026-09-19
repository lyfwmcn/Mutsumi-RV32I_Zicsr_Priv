`timescale 1ns / 1ns

// 9.4 ns
module ex2_stage (
    // 全局参数
    input             clk,
    input             flush,
    input             stall,

    // 流水线参数
    input             ex2_aluinausem1,
    input             ex2_aluinbusem1,
    input             ex2_csr_wr,
    input             ex2_data_ren,
    input             ex2_data_wen,
    input             ex2_ebreak,
    input             ex2_ecall,
    input             ex2_instr_access_fault,
    input             ex2_instr_illegal_fault,
    input             ex2_instr_page_fault,
    input             ex2_is_csr,
    input             ex2_is_instr,
    input             ex2_predtaken,
    input             ex2_reg_wr,
    input             ex2_ret,
    input             ex2_ret_type,
    input             ex2_rs1usem1,
    input             ex2_rs2usem1,
    input      [1:0]  ex2_csr_src,
    input      [2:0]  ex2_mem_ctr,
    input      [2:0]  ex2_reg_src,
    input      [4:0]  ex2_branch_ctr,
    input      [4:0]  ex2_rd,
    input      [5:0]  ex2_alu_ctr,
    input      [11:0] ex2_csr_rd,
    input      [31:0] ex2_alu_in_a,
    input      [31:0] ex2_alu_in_b,
    input      [31:0] ex2_csr_out,
    input      [31:0] ex2_imm,
    input      [31:0] ex2_instr,
    input      [31:0] ex2_pc,
    input      [31:0] ex2_pcplus4,
    input      [31:0] ex2_pcplusimm,
    input      [31:0] ex2_reg_out_a,
    input      [31:0] ex2_reg_out_b,
    output reg        m1_zf,
    output reg        m1_cf,
    output reg        m1_sf,
    output reg        m1_of,
    output reg        m1_csr_wr,
    output reg        m1_data_ren,
    output reg        m1_data_wen,
    output reg        m1_ebreak,
    output reg        m1_ecall,
    output reg        m1_instr_access_fault,
    output reg        m1_instr_illegal_fault,
    output reg        m1_instr_page_fault,
    output reg        m1_is_csr,
    output reg        m1_is_instr,
    output reg        m1_predtaken,
    output reg        m1_reg_wr,
    output reg        m1_ret,
    output reg        m1_ret_type,
    output reg [2:0]  m1_mem_ctr,
    output reg [2:0]  m1_reg_src,
    output reg [4:0]  m1_branch_ctr,
    output reg [4:0]  m1_rd,
    output reg [11:0] m1_csr_rd,
    output reg [31:0] m1_alu_out,
    output reg [31:0] m1_csr_out,
    output reg [31:0] m1_imm,
    output reg [31:0] m1_instr,
    output reg [31:0] m1_pc,
    output reg [31:0] m1_pcplus4,
    output reg [31:0] m1_pcplusimm,
    output reg [31:0] m1_raw_csr_in,
    output reg [31:0] m1_raw_reg_in,
    output reg [31:0] m1_reg_out_b
);

wire ex2_zf;
wire ex2_cf;
wire ex2_sf;
wire ex2_of;
wire [31:0] ex2_alu_in_a_true;
wire [31:0] ex2_alu_in_b_true;
wire [31:0] ex2_raw_reg_in;
wire [31:0] ex2_alu_out;

wire [31:0] ex2_reg_out_a_true;
wire [31:0] ex2_reg_out_b_true;
wire [31:0] ex2_raw_csr_in;

initial begin
    m1_zf = 1'h1;
    m1_cf = 1'h0;
    m1_sf = 1'h0;
    m1_of = 1'h0;
    m1_csr_wr = 1'h0;
    m1_data_ren = 1'h0;
    m1_data_wen = 1'h0;
    m1_ebreak = 1'h0;
    m1_ecall = 1'h0;
    m1_instr_access_fault = 1'h0;
    m1_instr_illegal_fault = 1'h0;
    m1_instr_page_fault = 1'h0;
    m1_is_csr = 1'h0;
    m1_is_instr = 1'h0;
    m1_predtaken = 1'h0;
    m1_reg_wr = 1'h1;
    m1_ret = 1'h0;
    m1_ret_type = 1'h0;
    m1_mem_ctr = 3'h0;
    m1_reg_src = 3'h0;
    m1_branch_ctr = 5'h0;
    m1_rd = 5'h0;
    m1_csr_rd = 12'h0;
    m1_alu_out = 32'h0;
    m1_csr_out = 32'h0;
    m1_imm = 32'h0;
    m1_instr = 32'h13;
    m1_pc = 32'h0;
    m1_pcplus4 = 32'h4;
    m1_pcplusimm = 32'h0;
    m1_raw_csr_in = 32'h0;
    m1_raw_reg_in = 32'h0;
    m1_reg_out_b = 32'h0;
end

always @(posedge clk) begin
    if (flush) begin
        m1_zf <= 1'h0;
        m1_cf <= 1'h0;
        m1_sf <= 1'h0;
        m1_of <= 1'h0;
        m1_csr_wr <= 1'h0;
        m1_data_ren <= 1'h0;
        m1_data_wen <= 1'h0;
        m1_ebreak <= 1'h0;
        m1_ecall <= 1'h0;
        m1_instr_access_fault <= 1'h0;
        m1_instr_illegal_fault <= 1'h0;
        m1_instr_page_fault <= 1'h0;
        m1_is_csr <= 1'h0;
        m1_is_instr <= 1'h0;
        m1_predtaken <= 1'h0;
        m1_reg_wr <= 1'h1;
        m1_ret <= 1'h0;
        m1_ret_type <= 1'h0;
        m1_mem_ctr <= 3'h0;
        m1_reg_src <= 3'h0;
        m1_branch_ctr <= 5'h0;
        m1_rd <= 5'h0;
        m1_csr_rd <= 12'h0;
        m1_alu_out <= 32'h0;
        m1_csr_out <= 32'h0;
        m1_imm <= 32'h0;
        m1_instr <= 32'h13;
        m1_pc <= 32'h0;
        m1_pcplus4 <= 32'h4;
        m1_pcplusimm <= 32'h0;
        m1_raw_csr_in <= 32'h0;
        m1_raw_reg_in <= 32'h0;
        m1_reg_out_b <= 32'h0;
    end
    else if (!stall) begin
        m1_zf <= ex2_zf;
        m1_cf <= ex2_cf;
        m1_sf <= ex2_sf;
        m1_of <= ex2_of;
        m1_csr_wr <= ex2_csr_wr;
        m1_data_ren <= ex2_data_ren;
        m1_data_wen <= ex2_data_wen;
        m1_ebreak <= ex2_ebreak;
        m1_ecall <= ex2_ecall;
        m1_instr_access_fault <= ex2_instr_access_fault;
        m1_instr_illegal_fault <= ex2_instr_illegal_fault;
        m1_instr_page_fault <= ex2_instr_page_fault;
        m1_is_csr <= ex2_is_csr;
        m1_is_instr <= ex2_is_instr;
        m1_predtaken <= ex2_predtaken;
        m1_reg_wr <= ex2_reg_wr;
        m1_ret <= ex2_ret;
        m1_ret_type <= ex2_ret_type;
        m1_mem_ctr <= ex2_mem_ctr;
        m1_reg_src <= ex2_reg_src;
        m1_branch_ctr <= ex2_branch_ctr;
        m1_rd <= ex2_rd;
        m1_csr_rd <= ex2_csr_rd;
        m1_alu_out <= ex2_alu_out;
        m1_csr_out <= ex2_csr_out;
        m1_imm <= ex2_imm;
        m1_instr <= ex2_instr;
        m1_pc <= ex2_pc;
        m1_pcplus4 <= ex2_pcplus4;
        m1_pcplusimm <= ex2_pcplusimm;
        m1_raw_csr_in <= ex2_raw_csr_in;
        m1_raw_reg_in <= ex2_raw_reg_in;
        m1_reg_out_b <= ex2_reg_out_b_true;
    end
end

assign ex2_reg_out_a_true = ex2_rs1usem1 ? m1_raw_reg_in : ex2_reg_out_a;
assign ex2_reg_out_b_true = ex2_rs2usem1 ? m1_raw_reg_in : ex2_reg_out_b;

assign ex2_alu_in_a_true = ex2_aluinausem1 ? m1_raw_reg_in : ex2_alu_in_a;
assign ex2_alu_in_b_true = ex2_aluinbusem1 ? m1_raw_reg_in : ex2_alu_in_b;
assign ex2_raw_reg_in = ex2_reg_src == 3'h0 ? ex2_alu_out :
                        ex2_reg_src == 3'h1 ? ex2_pcplus4 :
                        ex2_reg_src == 3'h2 ? ex2_pcplusimm :
                        ex2_reg_src == 3'h3 ? 32'h0 :        // load data not available in EX2; load-use is covered by mem_wait
                        ex2_reg_src == 3'h4 ? ex2_imm :
                        ex2_reg_src == 3'h5 ? ex2_csr_out :
                        32'h0;

assign ex2_raw_csr_in = ex2_csr_src == 2'h0 ? ex2_alu_out :
                        ex2_csr_src == 2'h1 ? ex2_reg_out_a_true :
                        ex2_csr_src == 2'h2 ? ex2_imm :
                        32'h0;

alu alu (
    .alu_ctr (ex2_alu_ctr),
    .alu_in_a(ex2_alu_in_a_true),
    .alu_in_b(ex2_alu_in_b_true),
    .zf      (ex2_zf),
    .cf      (ex2_cf),
    .sf      (ex2_sf),
    .of      (ex2_of),
    .alu_out (ex2_alu_out)
);

endmodule
