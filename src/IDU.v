`timescale 1ns / 1ns

// 需确保 Privilege = 2'h0, 2'h1, 2'h3
module IDU (
    input [1:0] Privilege,
    input [31:0] Instr,
    output BusAused,
    output BusBused,
    output CSRWr,
    output DataREN,
    output DataWEN,
    output Ebreak,
    output Ecall,
    output InstrFault,
    output IsCSR,
    output PredTaken,
    output RegWr,
    output Ret,
    output RetType,
    output [1:0] ALUASrc,
    output [1:0] ALUBSrc,
    output [1:0] CSRSrc,
    output [2:0] MemCtr,
    output [2:0] RegSrc,
    output [4:0] BranchCtr,
    output [4:0] Rd,
    output [4:0] Rs1,
    output [4:0] Rs2,
    output [5:0] ALUCtr,
    output [11:0] CSRRd,
    output [31:0] imm
);

wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;
wire [4:0] _Rs1;
wire [4:0] _Rs2;
wire [4:0] _Rd;
wire [11:0] _CSRRd;
wire [11:0] SystemCode;

assign opcode = Instr[6:0];
assign funct3 = Instr[14:12];
assign funct7 = Instr[31:25];
assign _Rs1 = Instr[19:15];
assign _Rs2 = Instr[24:20];
assign _Rd = Instr[11:7];
assign _CSRRd = Instr[31:20];
assign SystemCode = Instr[31:20];

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

wire [31:0] _imm;
assign _imm = optype == 4'h7 ? {{20{Instr[31]}}, Instr[31:25], Instr[11:7]} :
              optype == 4'h8 ? {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'h0} :
              optype == 4'h9 ? {{11{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'h0} :
              optype == 4'h5 || optype == 4'h6 ? {Instr[31:12], 12'h0} :
              optype == 4'h2 && (funct3 == 3'h1 || funct3 == 3'h5) ? {27'h0, Instr[24:20]} :
              optype >= 4'h2 && optype <= 4'h4 ? {{20{Instr[31]}}, Instr[31:20]} :
              optype == 4'hb ? {27'h0, Instr[19:15]} :
              32'h0;

wire InstrFaults [12:0];
assign InstrFaults[0] = 1'h1;
// invalid 指令错误
assign InstrFaults[1] = funct7[6] != 1'h0 || funct7[4:0] != 5'h0 || (funct3 != 3'h0 && funct3 != 3'h5 && funct7[5] == 1'h1);
// R 型指令检查 funct7
assign InstrFaults[2] = (funct3 == 3'h1 && _imm[11:5] != 7'h0) || (funct3 == 3'h5 && (_imm[11] != 1'h0 || _imm[9:5] != 5'h0));
// I 型指令检查 srli 和 srai 的 funct7
assign InstrFaults[3] = funct3 == 3'h3 || funct3 == 3'h6 || funct3 == 3'h7;
// load 型指令检查 funct3
assign InstrFaults[4] = funct3 != 3'h0;
// jalr 检查 funct3
assign InstrFaults[5] = 1'h0;
// lui 无错误
assign InstrFaults[6] = 1'h0;
// auipc 无错误
assign InstrFaults[7] = funct3 >= 3'h3;
// S 型指令检查 funct3
assign InstrFaults[8] = funct3 == 3'h2 || funct3 == 3'h3;
// B 型指令检查 funct3
assign InstrFaults[9] = 1'h0;
// J 型指令无错误
wire CSRExist;
assign CSRExist = _CSRRd == 12'h100 ||
                  _CSRRd == 12'h104 ||
                  _CSRRd == 12'h105 ||
                  _CSRRd == 12'h140 ||
                  _CSRRd == 12'h141 ||
                  _CSRRd == 12'h142 ||
                  _CSRRd == 12'h143 ||
                  _CSRRd == 12'h144 ||
                  _CSRRd == 12'h180 ||
                  _CSRRd == 12'h300 ||
                  _CSRRd == 12'h301 ||
                  _CSRRd == 12'h302 ||
                  _CSRRd == 12'h303 ||
                  _CSRRd == 12'h304 ||
                  _CSRRd == 12'h305 ||
                  _CSRRd == 12'h340 ||
                  _CSRRd == 12'h341 ||
                  _CSRRd == 12'h342 ||
                  _CSRRd == 12'h343 ||
                  _CSRRd == 12'h344 ||
                  _CSRRd == 12'hB00 ||
                  _CSRRd == 12'hB02 ||
                  _CSRRd == 12'hB80 ||
                  _CSRRd == 12'hB82 ||
                  _CSRRd == 12'hF14;
wire CSRRXWr;
assign CSRRXWr = funct3 == 3'h1 || _Rs1 != 5'h0;
assign InstrFaults[10] = !CSRExist || Privilege < _CSRRd[9:8] || (CSRRXWr && _CSRRd[11:10] >= 2'h2);
// SYSTEM 型指令（funct3 == 1, 2, 3）
wire CSRRXIWr;
assign CSRRXIWr = funct3 == 3'h5 || _imm != 32'h0;
assign InstrFaults[11] = !CSRExist || Privilege < _CSRRd[9:8] || (CSRRXIWr && _CSRRd[11:10] >= 2'h2);
// SYSTEM 型指令（funct3 == 5, 6, 7）
wire SystemExist;
assign SystemExist = SystemCode == 12'h0 ||
                     SystemCode == 12'h1 ||
                     SystemCode == 12'h302 ||
                     SystemCode == 12'h102;
assign InstrFaults[12] = _Rs1 != 5'h0 || _Rd != 5'h0 || !SystemExist || (SystemCode == 12'h302 && Privilege < 2'h3) || (SystemCode == 12'h102 && Privilege < 2'h1);
// SYSTEM 型指令（funct3 == 0）
// 目前支持 ecall, ebreak, mret, sret
assign InstrFault = InstrFaults[optype];

assign Ebreak = !InstrFault && optype == 4'hc && SystemCode == 12'h1;
assign Ecall = !InstrFault && optype == 4'hc && SystemCode == 12'h0;
assign RegWr = InstrFault ? 1'h1 : optype != 4'h7 && optype != 4'h8 && optype != 4'hc;
assign Ret = !InstrFault && optype == 4'hc && (SystemCode == 12'h302 || SystemCode == 12'h102);
assign RetType = !InstrFault && SystemCode == 12'h102;
assign CSRWr = !InstrFault && ((optype == 4'ha && CSRRXWr) || (optype == 4'hb && CSRRXIWr));
assign IsCSR = !InstrFault && (optype == 4'ha || optype == 4'hb);
assign BusAused = InstrFault ? 1'h1 : optype != 4'h5 && optype != 4'h6 && optype != 4'h9 && optype != 4'hb && optype != 4'hc && (optype != 4'ha || CSRRXWr);
assign BusBused = !InstrFault && (optype == 4'h1 || optype == 4'h7 || optype == 4'h8);
// 需保证 BranchCtr[4:3] = 2'h0, 2'h3 时 PredTaken = 1'h0
assign PredTaken = !InstrFault && ((optype == 4'h8 && _imm[31] == 1'h1) || optype == 4'h9);
// 需保证 DataWEN = 1'h1 时 DataREN = 1'h0
assign DataREN = !InstrFault && optype == 4'h3;
// 需保证 DataREN = 1'h1 时 DataWEN = 1'h0
assign DataWEN = !InstrFault && optype == 4'h7;
assign CSRSrc = InstrFault ? 2'h0 :
                !CSRWr ? 2'h0 :
                optype == 4'ha ? (funct3 == 3'h1 ? 2'h1 : 2'h0) :
                optype == 4'hb ? (funct3 == 3'h5 ? 2'h2 : 2'h0) :
                2'h0;
assign ALUASrc = InstrFault ? 2'h0 :
                 optype == 4'h6 ? 2'h1 :
                 optype == 4'hb && CSRRXIWr ? 2'h2 :
                 2'h0;
assign ALUBSrc = InstrFault ? 2'h1 :
                 optype == 4'h1 || optype == 4'h8 ? 2'h0 :
                 (optype == 4'ha && CSRRXWr) || (optype == 4'hb && CSRRXIWr) ? (funct3[1:0] == 2'h2 || funct3[1:0] == 2'h3 ? 2'h2 : 2'h0) :
                 2'h1;
assign RegSrc = InstrFault ? 3'h0 :
                optype == 4'h5 ? 3'h3 :
                optype == 4'h3 ? 3'h2 :
                optype == 4'h4 || optype == 4'h9 ? 3'h1 :
                optype == 4'ha || optype == 4'hb ? 3'h4 :
                3'h0;
// 需保证 DataWEN = 1'h0 时 MemCtr: 3'h0-3'h2, 3'h4-3'h5, DataWEN = 1'h1 时 MemCtr: 3'h0-3'h2
assign MemCtr = InstrFault ? 3'h2 :
                optype == 4'h3 || optype == 4'h7 ? funct3 :
                3'h2;
// 需保证 BranchCtr[4:3] = 2'h0, 2'h2-2'h3 时 BranchCtr[2:0] = 3'h0，BranchCtr[4:3] = 2'h1 时 BranchCtr[2:0] = 3'h0-3'h1, 3'h4-3'h7
assign BranchCtr = InstrFault ? 5'h0 :
                   optype == 4'h8 ? {2'h1, funct3} :
                   optype == 4'h9 ? 5'h10 :
                   optype == 4'h4 ? 5'h18 :
                   5'h0;
assign Rs1 = !InstrFault ? _Rs1 : 5'h0;
assign Rs2 = !InstrFault ? _Rs2 : 5'h0;
assign Rd = !InstrFault ? _Rd : 5'h0;
// 需保证 ALUCtr[3:0]: 4‘h0-4'h8, 4'hd
assign ALUCtr = InstrFault ? 6'h0 :
                optype == 4'h1 ? {2'h0, funct7[5], funct3} :
                optype == 4'h2 ? {2'h0, funct3 == 3'h5 ? funct7[5] : 1'h0, funct3} :
                optype == 4'h8 ? 6'h8 :
                (optype == 4'ha && CSRRXWr) || (optype == 4'hb && CSRRXIWr) ? (funct3[1:0] == 2'h2 ? 6'h6 : (funct3[1:0] == 2'h3 ? 6'h17 : 6'h0)) :
                6'h0;
assign CSRRd = InstrFault ? 12'h0 :
               optype == 4'ha || optype == 4'hb ? _CSRRd :
               12'h0;
assign imm = !InstrFault ? _imm : 32'h0;

endmodule
