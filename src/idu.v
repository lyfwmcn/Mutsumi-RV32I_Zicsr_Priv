`timescale 1ns / 1ns

// 需确保 privilege = 2'h0, 2'h1, 2'h3
module idu (
    input  [1:0]  privilege,
    input  [31:0] instr,
    output        alu_src_a,
    output        csr_wr,
    output        data_ren,
    output        data_wen,
    output        ebreak,
    output        ecall,
    output        instr_illegal_fault,
    output        is_csr,
    output        predtaken,
    output        reg_out_a_used,
    output        reg_out_b_used,
    output        reg_wr,
    output        ret,
    output        ret_type,
    output [1:0]  alu_src_b,
    output [1:0]  csr_src,
    output [2:0]  mem_ctr,
    output [2:0]  reg_src,
    output [4:0]  branch_ctr,
    output [4:0]  rd,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [5:0]  alu_ctr,
    output [11:0] csr_rd,
    output [31:0] imm
);

// rs1 func rs2
// rs1 func imm
// rs1 + imm (addr)
// rs1 func csrout
// imm func csrout
// pc + imm (addr) 专用

// 之前
// rs1    rs2
// pc     imm
// imm    csrout

// 现在
// rs1     rs2
// imm     imm
//         csrout

wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;
wire [11:0] system_code;

assign opcode = instr[6:0];
assign funct3 = instr[14:12];
assign funct7 = instr[31:25];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign rd = instr[11:7];
assign csr_rd = instr[31:20];
assign system_code = instr[31:20];

wire [3:0] optype;
assign optype = opcode == 7'h73 ? (funct3 == 3'h0 ? 4'hc : (funct3 <=  3'h3 ? 4'ha : (funct3 >= 3'h5 ? 4'hb : 4'h0))) :  // SYSTEM
                opcode == 7'h6f ? 4'h9 :  // J
                opcode == 7'h63 ? 4'h8 :  // B
                opcode == 7'h23 ? 4'h7 :  // S
                opcode == 7'h17 ? 4'h6 :  // auipc
                opcode == 7'h37 ? 4'h5 :  // lui
                opcode == 7'h67 ? 4'h4 :  // jalr
                opcode == 7'h3  ? 4'h3 :  // load
                opcode == 7'h13 ? 4'h2 :  // I
                opcode == 7'h33 ? 4'h1 :  // R
                4'h0;                     // invalid

assign imm = optype == 4'h7 ? {{20{instr[31]}}, instr[31:25], instr[11:7]} :
             optype == 4'h8 ? {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'h0} :
             optype == 4'h9 ? {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'h0} :
             optype == 4'h5 || optype == 4'h6 ? {instr[31:12], 12'h0} :
             optype == 4'h2 && (funct3 == 3'h1 || funct3 == 3'h5) ? {27'h0, instr[24:20]} :
             optype >= 4'h2 && optype <= 4'h4 ? {{20{instr[31]}}, instr[31:20]} :
             optype == 4'hb ? {27'h0, instr[19:15]} :
             32'h0;

wire instr_illegal_faults [12:0];
assign instr_illegal_faults[0] = 1'h1;
// invalid 指令错误
assign instr_illegal_faults[1] = funct7[6] != 1'h0 || funct7[4:0] != 5'h0 || (funct3 != 3'h0 && funct3 != 3'h5 && funct7[5] == 1'h1);
// R 型指令检查 funct7
assign instr_illegal_faults[2] = (funct3 == 3'h1 && imm[11:5] != 7'h0) || (funct3 == 3'h5 && (imm[11] != 1'h0 || imm[9:5] != 5'h0));
// I 型指令检查 srli 和 srai 的 funct7
assign instr_illegal_faults[3] = funct3 == 3'h3 || funct3 == 3'h6 || funct3 == 3'h7;
// load 型指令检查 funct3
assign instr_illegal_faults[4] = funct3 != 3'h0;
// jalr 检查 funct3
assign instr_illegal_faults[5] = 1'h0;
// lui 无错误
assign instr_illegal_faults[6] = 1'h0;
// auipc 无错误
assign instr_illegal_faults[7] = funct3 >= 3'h3;
// S 型指令检查 funct3
assign instr_illegal_faults[8] = funct3 == 3'h2 || funct3 == 3'h3;
// B 型指令检查 funct3
assign instr_illegal_faults[9] = 1'h0;
// J 型指令无错误
wire csr_exist;
assign csr_exist = csr_rd == 12'h100 ||
                   csr_rd == 12'h104 ||
                   csr_rd == 12'h105 ||
                   csr_rd == 12'h140 ||
                   csr_rd == 12'h141 ||
                   csr_rd == 12'h142 ||
                   csr_rd == 12'h143 ||
                   csr_rd == 12'h144 ||
                   csr_rd == 12'h180 ||
                   csr_rd == 12'h300 ||
                   csr_rd == 12'h301 ||
                   csr_rd == 12'h302 ||
                   csr_rd == 12'h303 ||
                   csr_rd == 12'h304 ||
                   csr_rd == 12'h305 ||
                   csr_rd == 12'h340 ||
                   csr_rd == 12'h341 ||
                   csr_rd == 12'h342 ||
                   csr_rd == 12'h343 ||
                   csr_rd == 12'h344 ||
                   csr_rd == 12'hB00 ||
                   csr_rd == 12'hB02 ||
                   csr_rd == 12'hB80 ||
                   csr_rd == 12'hB82 ||
                   csr_rd == 12'hF14;
wire csr_reg_wr_en;
assign csr_reg_wr_en = funct3 == 3'h1 || rs1 != 5'h0;
assign instr_illegal_faults[10] = !csr_exist || privilege < csr_rd[9:8] || (csr_reg_wr_en && csr_rd[11:10] >= 2'h2);
// SYSTEM 型指令（funct3 == 1, 2, 3）
wire csr_imm_wr_en;
assign csr_imm_wr_en = funct3 == 3'h5 || imm != 32'h0;
assign instr_illegal_faults[11] = !csr_exist || privilege < csr_rd[9:8] || (csr_imm_wr_en && csr_rd[11:10] >= 2'h2);
// SYSTEM 型指令（funct3 == 5, 6, 7）
wire system_exist;
assign system_exist = system_code == 12'h0 ||
                      system_code == 12'h1 ||
                      system_code == 12'h302 ||
                      system_code == 12'h102;
assign instr_illegal_faults[12] = rs1 != 5'h0 || rd != 5'h0 || !system_exist || (system_code == 12'h302 && privilege < 2'h3) || (system_code == 12'h102 && privilege < 2'h1);
// SYSTEM 型指令（funct3 == 0）
// 目前支持 ecall, ebreak, mret, sret
assign instr_illegal_fault = instr_illegal_faults[optype];

assign ebreak = !instr_illegal_faults[12] && optype == 4'hc && system_code == 12'h1;
assign ecall = !instr_illegal_faults[12] && optype == 4'hc && system_code == 12'h0;
assign reg_wr = !instr_illegal_fault && optype != 4'h7 && optype != 4'h8 && optype != 4'hc;
assign ret = !instr_illegal_faults[12] && optype == 4'hc && (system_code == 12'h302 || system_code == 12'h102);
assign ret_type = system_code == 12'h102;
assign csr_wr = (optype == 4'ha && !instr_illegal_faults[10] && csr_reg_wr_en) || (optype == 4'hb && !instr_illegal_faults[11] && csr_imm_wr_en);
assign is_csr = (optype == 4'ha && !instr_illegal_faults[10]) || (optype == 4'hb && !instr_illegal_faults[11]);
assign reg_out_a_used = !instr_illegal_fault && optype != 4'h5 && optype != 4'h6 && optype != 4'h9 && optype != 4'hb && optype != 4'hc && (optype != 4'ha || csr_reg_wr_en);
assign reg_out_b_used = (optype == 4'h1 && !instr_illegal_faults[1]) || (optype == 4'h7 && !instr_illegal_faults[7]) || (optype == 4'h8 && !instr_illegal_faults[8]);
// 需保证 branch_ctr[4:3] = 2'h0, 2'h3 时 predtaken = 1'h0
assign predtaken = (optype == 4'h8 && !instr_illegal_faults[8] && imm[31] == 1'h1) || (optype == 4'h9 && !instr_illegal_faults[9]);
// 需保证 data_wen = 1'h1 时 data_ren = 1'h0
assign data_ren = optype == 4'h3 && !instr_illegal_faults[3];
// 需保证 data_ren = 1'h1 时 data_wen = 1'h0
assign data_wen = optype == 4'h7 && !instr_illegal_faults[7];
assign csr_src = optype == 4'ha ? (funct3 == 3'h1 ? 2'h1 : 2'h0) :
                 (funct3 == 3'h5 ? 2'h2 : 2'h0);
// 可能可以简化
assign alu_src_a = optype == 4'hb && csr_imm_wr_en ? 1'h1 : 1'h0;
// 可能可以简化
assign alu_src_b = optype == 4'h1 || optype == 4'h8 ? 2'h0 :
                   (optype == 4'ha && csr_reg_wr_en) || (optype == 4'hb && csr_imm_wr_en) ? (funct3[1:0] == 2'h2 || funct3[1:0] == 2'h3 ? 2'h2 : 2'h0) :
                   2'h1;
assign reg_src = optype == 4'h6 ? 3'h2 :
                 optype == 4'h5 ? 3'h4 :
                 optype == 4'h3 ? 3'h3 :
                 optype == 4'h4 || optype == 4'h9 ? 3'h1 :
                 optype == 4'ha || optype == 4'hb ? 3'h5 :
                 3'h0;
// 需保证 data_wen = 1'h0 时 mem_ctr: 3'h0-3'h2, 3'h4-3'h5, data_wen = 1'h1 时 mem_ctr: 3'h0-3'h2
assign mem_ctr = funct3;
// 需保证 branch_ctr[4:3] = 2'h0, 2'h2-2'h3 时 branch_ctr[2:0] = 3'h0，branch_ctr[4:3] = 2'h1 时 branch_ctr[2:0] = 3'h0-3'h1, 3'h4-3'h7
assign branch_ctr = optype == 4'h8 && !instr_illegal_faults[8] ? {2'h1, funct3} :
                    optype == 4'h9 && !instr_illegal_faults[9] ? 5'h10 :
                    optype == 4'h4 && !instr_illegal_faults[4] ? 5'h18 :
                    5'h0;
// 需保证 alu_ctr[3:0]: 4'h0-4'h8, 4'hd
assign alu_ctr = optype == 4'h1 ? {2'h0, funct7[5], funct3} :
                 optype == 4'h2 ? {2'h0, funct3 == 3'h5 ? funct7[5] : 1'h0, funct3} :
                 optype == 4'h8 ? 6'h8 :
                 (optype == 4'ha && csr_reg_wr_en) || (optype == 4'hb && csr_imm_wr_en) ? (funct3[1:0] == 2'h2 ? 6'h6 : (funct3[1:0] == 2'h3 ? 6'h17 : 6'h0)) :
                 6'h0;

endmodule
