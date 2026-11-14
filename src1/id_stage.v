`timescale 1ns / 1ns

module id_stage (
    // 全局参数
    input             clk,
    input             rst_n,
    input             flush,
    input             stall,
    input             TSR,
    input             TVM,
    input             TW,
    input      [1:0]  privilege,
    output            id_wait,

    // 旁路参数
    input      [31:0] id_csr_out,
    input      [31:0] id_reg_out_a,
    input      [31:0] id_reg_out_b,
    output            id_jump,
    output     [4:0]  id_rs1,
    output     [4:0]  id_rs2,
    output     [11:0] id_csr_rd,
    output     [30:0] id_jump_addr,

    input             me_is_instr,
    input             me_reg_wr,
    input      [2:0]  me_reg_src,
    input      [4:0]  me_rd,
    input      [31:0] me_raw_reg_in,

    input             wb_is_instr,
    input             wb_reg_wr,
    input      [4:0]  wb_rd,
    input      [31:0] wb_reg_in,

    // 流水线参数
    input             id_instr_access_fault,
    input             id_instr_page_fault,
    input             id_is_instr,
    input      [30:0] id_pc,
    input      [30:0] id_pcplus,
    input      [31:0] id_instr,
    output reg        ex_alu_in_a_src,
    output reg        ex_alu_in_b_src,
    output reg        ex_csr_wr,
    output reg        ex_ebreak,
    output reg        ex_ecall,
    output reg        ex_instr_access_fault,
    output reg        ex_instr_illegal_fault,
    output reg        ex_instr_page_fault,
    output reg        ex_is_csr,
    output reg        ex_is_instr,
    output reg        ex_mem_valid,
    output reg        ex_reg_wr,
    output reg        ex_ret,
    output reg        ex_ret_type,
    output reg        ex_rs2_src,
    output reg        ex_wfi,
    output reg [2:0]  ex_csr_ctr,
    output reg [2:0]  ex_reg_src,
    output reg [3:0]  ex_alu_ctr,
    output reg [4:0]  ex_branch_ctr,
    output reg [4:0]  ex_mem_ctr,
    output reg [4:0]  ex_rd,
    output reg [11:0] ex_csr_rd,
    output reg [30:0] ex_pc,
    output reg [30:0] ex_pcplus,
    output reg [30:0] ex_pcplusimm,
    output reg [31:0] ex_alu_in_a,
    output reg [31:0] ex_alu_in_b,
    output reg [31:0] ex_csr_out,
    output reg [31:0] ex_imm,
    output reg [31:0] ex_reg_out_b,
    output reg [31:0] ex_instr
);

wire        id_alu_in_a_src;
wire        id_alu_in_b_src;
wire        id_alu_src_a;
wire        id_alu_src_b;
wire        id_csr_wr;
wire        id_ebreak;
wire        id_ecall;
wire        id_instr_illegal_fault;
wire        id_is_csr;
wire        id_mem_valid;
wire        id_reg_out_a_used;
wire        id_reg_out_b_used;
wire        id_reg_wr;
wire        id_ret;
wire        id_ret_type;
wire        id_rs2_src;
wire        id_wfi;
wire [2:0]  id_csr_ctr;
wire [2:0]  id_reg_src;
wire [3:0]  id_alu_ctr;
wire [4:0]  id_branch_ctr;
wire [4:0]  id_mem_ctr;
wire [4:0]  id_rd;
wire [30:0] id_pcplusimm;
wire [31:0] id_alu_in_a;
wire [31:0] id_alu_in_b;
wire [31:0] id_imm;
wire [31:0] id_reg_out_b_true;

wire        reg_wait;
wire        csr_wait;

assign id_jump_addr = id_pcplusimm;
assign id_wait = reg_wait || csr_wait;

idu u_idu (
    .is_instr           (id_is_instr),
    .TSR                (TSR),
    .TVM                (TVM),
    .TW                 (TW),
    .privilege          (privilege),
    .pc                 (id_pc),
    .instr              (id_instr),

    .ebreak             (id_ebreak),
    .ecall              (id_ecall),
    .instr_illegal_fault(id_instr_illegal_fault),

    .ret                (id_ret),
    .ret_type           (id_ret_type),

    .wfi                (id_wfi),

    .alu_src_a          (id_alu_src_a),
    .alu_src_b          (id_alu_src_b),
    .alu_ctr            (id_alu_ctr),

    .reg_out_a_used     (id_reg_out_a_used),
    .reg_out_b_used     (id_reg_out_b_used),
    .rs1                (id_rs1),
    .rs2                (id_rs2),

    .reg_wr             (id_reg_wr),
    .reg_src            (id_reg_src),
    .rd                 (id_rd),

    .csr_wr             (id_csr_wr),
    .is_csr             (id_is_csr),
    .csr_ctr            (id_csr_ctr),
    .csr_rd             (id_csr_rd),

    .mem_valid          (id_mem_valid),
    .mem_ctr            (id_mem_ctr),

    .jump               (id_jump),
    .branch_ctr         (id_branch_ctr),
    .pcplusimm          (id_pcplusimm),

    .imm                (id_imm)
);

reg_bypass u_reg_bypass (
    .id_reg_out_a_used(id_reg_out_a_used),
    .id_reg_out_b_used(id_reg_out_b_used),
    .id_alu_src_a     (id_alu_src_a),
    .id_alu_src_b     (id_alu_src_b),
    .id_rs1           (id_rs1),
    .id_rs2           (id_rs2),
    .id_imm           (id_imm),
    .id_reg_out_a     (id_reg_out_a),
    .id_reg_out_b     (id_reg_out_b),

    .ex_reg_wr        (ex_reg_wr),
    .ex_reg_src       (ex_reg_src),
    .ex_rd            (ex_rd),

    .me_reg_wr        (me_reg_wr),
    .me_reg_src       (me_reg_src),
    .me_rd            (me_rd),
    .me_raw_reg_in    (me_raw_reg_in),

    .wb_reg_wr        (wb_reg_wr),
    .wb_rd            (wb_rd),
    .wb_reg_in        (wb_reg_in),

    .reg_wait         (reg_wait),
    .id_rs2_src       (id_rs2_src),
    .id_alu_in_a_src  (id_alu_in_a_src),
    .id_alu_in_b_src  (id_alu_in_b_src),
    .id_alu_in_a      (id_alu_in_a),
    .id_alu_in_b      (id_alu_in_b),
    .id_reg_out_b_true(id_reg_out_b_true)
);

csr_hazard u_csr_hazard (
    .id_is_csr  (id_is_csr),

    .ex_is_instr(ex_is_instr),
    .me_is_instr(me_is_instr),
    .wb_is_instr(wb_is_instr),

    .csr_wait (csr_wait)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // ex_alu_in_a_src <= ;
        // ex_alu_in_b_src <= ;
        // ex_csr_wr <= ;
        ex_ebreak <= 1'h0;
        ex_ecall <= 1'h0;
        ex_instr_access_fault <= 1'h0;
        ex_instr_illegal_fault <= 1'h0;
        ex_instr_page_fault <= 1'h0;
        ex_is_csr <= 1'h0;
        ex_is_instr <= 1'h0;
        ex_mem_valid <= 1'h0;
        ex_reg_wr <= 1'h0;
        ex_ret <= 1'h0;
        // ex_ret_type <= ;
        // ex_rs2_src <= ;
        ex_wfi <= 1'h0;
        // ex_csr_ctr <= ;
        // ex_reg_src <= ;
        // ex_alu_ctr <= ;
        ex_branch_ctr <= 5'h0;
        // ex_mem_ctr <= ;
        // ex_rd <= ;
        // ex_csr_rd <= ;
        // ex_pc <= ;
        // ex_pcplus <= ;
        // ex_pcplusimm <= ;
        // ex_alu_in_a <= ;
        // ex_alu_in_b <= ;
        // ex_csr_out <= ;
        // ex_imm <= ;
        // ex_reg_out_b <= ;
        // ex_instr <= ;
    end
    else if (flush) begin
        // ex_alu_in_a_src <= ;
        // ex_alu_in_b_src <= ;
        // ex_csr_wr <= ;
        ex_ebreak <= 1'h0;
        ex_ecall <= 1'h0;
        ex_instr_access_fault <= 1'h0;
        ex_instr_illegal_fault <= 1'h0;
        ex_instr_page_fault <= 1'h0;
        ex_is_csr <= 1'h0;
        ex_is_instr <= 1'h0;
        ex_mem_valid <= 1'h0;
        ex_reg_wr <= 1'h0;
        ex_ret <= 1'h0;
        // ex_ret_type <= ;
        // ex_rs2_src <= ;
        ex_wfi <= 1'h0;
        // ex_csr_ctr <= ;
        // ex_reg_src <= ;
        // ex_alu_ctr <= ;
        ex_branch_ctr <= 5'h0;
        // ex_mem_ctr <= ;
        // ex_rd <= ;
        // ex_csr_rd <= ;
        // ex_pc <= ;
        // ex_pcplus <= ;
        // ex_pcplusimm <= ;
        // ex_alu_in_a <= ;
        // ex_alu_in_b <= ;
        // ex_csr_out <= ;
        // ex_imm <= ;
        // ex_reg_out_b <= ;
        // ex_instr <= ;
    end
    else if (!stall) begin
        ex_alu_in_a_src <= id_alu_in_a_src;
        ex_alu_in_b_src <= id_alu_in_b_src;
        ex_csr_wr <= id_csr_wr;
        ex_ebreak <= id_ebreak;
        ex_ecall <= id_ecall;
        ex_instr_access_fault <= id_instr_access_fault;
        ex_instr_illegal_fault <= id_instr_illegal_fault;
        ex_instr_page_fault <= id_instr_page_fault;
        ex_is_csr <= id_is_csr;
        ex_is_instr <= id_is_instr;
        ex_mem_valid <= id_mem_valid;
        ex_reg_wr <= id_reg_wr;
        ex_ret <= id_ret;
        ex_ret_type <= id_ret_type;
        ex_rs2_src <= id_rs2_src;
        ex_wfi <= id_wfi;
        ex_csr_ctr <= id_csr_ctr;
        ex_reg_src <= id_reg_src;
        ex_alu_ctr <= id_alu_ctr;
        ex_branch_ctr <= id_branch_ctr;
        ex_mem_ctr <= id_mem_ctr;
        ex_rd <= id_rd;
        ex_csr_rd <= id_csr_rd;
        ex_pc <= id_pc;
        ex_pcplus <= id_pcplus;
        ex_pcplusimm <= id_pcplusimm;
        ex_alu_in_a <= id_alu_in_a;
        ex_alu_in_b <= id_alu_in_b;
        ex_csr_out <= id_csr_out;
        ex_imm <= id_imm;
        ex_reg_out_b <= id_reg_out_b_true;
        ex_instr <= id_instr;
    end
end

endmodule
