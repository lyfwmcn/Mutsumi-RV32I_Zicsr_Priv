`timescale 1ns / 1ns

module EXStage (
    // 全局参数
    input CLK,
    input RST,
    input Flush,
    input Stall,

    // 旁路参数
    output [31:0] EXBusW,

    // 流水线参数
    input EXCSRWr,
    input EXDataREN,
    input EXDataWEN,
    input EXEbreak,
    input EXEcall,
    input EXInstrAccessFault,
    input EXInstrFault,
    input EXInstrPageFault,
    input EXIsCSR,
    input EXIsInstr,
    input EXPredTaken,
    input EXRegWr,
    input EXRet,
    input EXRetType,
    input [1:0] EXALUASrc,
    input [1:0] EXALUBSrc,
    input [1:0] EXCSRSrc,
    input [2:0] EXMemCtr,
    input [2:0] EXRegSrc,
    input [4:0] EXBranchCtr,
    input [4:0] EXRd,
    input [5:0] EXALUCtr,
    input [11:0] EXCSRRd,
    input [31:0] EXBusA,
    input [31:0] EXBusB,
    input [31:0] EXCSRout,
    input [31:0] EXimm,
    input [31:0] EXInstr,
    input [31:0] EXPC,
    input [31:0] EXPCCtrPC1,
    input [31:0] EXPCPlus4,
    output reg M1ZF,
    output reg M1CF,
    output reg M1SF,
    output reg M1OF,
    output reg M1CSRWr,
    output reg M1DataREN,
    output reg M1DataWEN,
    output reg M1Ebreak,
    output reg M1Ecall,
    output reg M1InstrAccessFault,
    output reg M1InstrFault,
    output reg M1InstrPageFault,
    output reg M1IsCSR,
    output reg M1IsInstr,
    output reg M1PredTaken,
    output reg M1RegWr,
    output reg M1Ret,
    output reg M1RetType,
    output reg [2:0] M1MemCtr,
    output reg [2:0] M1RegSrc,
    output reg [4:0] M1BranchCtr,
    output reg [4:0] M1Rd,
    output reg [11:0] M1CSRRd,
    output reg [31:0] M1BusA,
    output reg [31:0] M1BusB,
    output reg [31:0] M1BusW,
    output reg [31:0] M1CSRin,
    output reg [31:0] M1CSRout,
    output reg [31:0] M1imm,
    output reg [31:0] M1Instr,
    output reg [31:0] M1PC,
    output reg [31:0] M1PCCtrPC1,
    output reg [31:0] M1PCPlus4
);

wire EXZF;
wire EXCF;
wire EXSF;
wire EXOF;
wire [31:0] EXCSRin;
wire [31:0] EXRawCSRin;
wire [31:0] OperA;
wire [31:0] OperB;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        M1ZF <= 1'h1;
        M1CF <= 1'h0;
        M1SF <= 1'h0;
        M1OF <= 1'h0;
        M1CSRWr <= 1'h0;
        M1DataREN <= 1'h0;
        M1DataWEN <= 1'h0;
        M1Ebreak <= 1'h0;
        M1Ecall <= 1'h0;
        M1InstrAccessFault <= 1'h0;
        M1InstrFault <= 1'h0;
        M1InstrPageFault <= 1'h0;
        M1IsCSR <= 1'h0;
        M1IsInstr <= 1'h0;
        M1PredTaken <= 1'h0;
        M1RegWr <= 1'h1;
        M1Ret <= 1'h0;
        M1RetType <= 1'h0;
        M1MemCtr <= 3'h2;
        M1RegSrc <= 3'h0;
        M1BranchCtr <= 5'h0;
        M1Rd <= 5'h0;
        M1CSRRd <= 12'h0;
        M1BusA <= 32'h0;
        M1BusB <= 32'h0;
        M1BusW <= 32'h0;
        M1CSRin <= 32'h0;
        M1CSRout <= 32'h0;
        M1imm <= 32'h0;
        M1Instr <= 32'h13;
        M1PC <= 32'h0;
        M1PCCtrPC1 <= 32'h4;
        M1PCPlus4 <= 32'h4;
    end
    else if (Flush) begin
        M1ZF <= 1'h1;
        M1CF <= 1'h0;
        M1SF <= 1'h0;
        M1OF <= 1'h0;
        M1CSRWr <= 1'h0;
        M1DataREN <= 1'h0;
        M1DataWEN <= 1'h0;
        M1Ebreak <= 1'h0;
        M1Ecall <= 1'h0;
        M1InstrAccessFault <= 1'h0;
        M1InstrFault <= 1'h0;
        M1InstrPageFault <= 1'h0;
        M1IsCSR <= 1'h0;
        M1IsInstr <= 1'h0;
        M1PredTaken <= 1'h0;
        M1RegWr <= 1'h1;
        M1Ret <= 1'h0;
        M1RetType <= 1'h0;
        M1MemCtr <= 3'h2;
        M1RegSrc <= 3'h0;
        M1BranchCtr <= 5'h0;
        M1Rd <= 5'h0;
        M1CSRRd <= 12'h0;
        M1BusA <= 32'h0;
        M1BusB <= 32'h0;
        M1BusW <= 32'h0;
        M1CSRin <= 32'h0;
        M1CSRout <= 32'h0;
        M1imm <= 32'h0;
        M1Instr <= 32'h13;
        M1PC <= 32'h0;
        M1PCCtrPC1 <= 32'h4;
        M1PCPlus4 <= 32'h4;
    end
    else if (!Stall) begin
        M1ZF <= EXZF;
        M1CF <= EXCF;
        M1SF <= EXSF;
        M1OF <= EXOF;
        M1CSRWr <= EXCSRWr;
        M1DataREN <= EXDataREN;
        M1DataWEN <= EXDataWEN;
        M1Ebreak <= EXEbreak;
        M1Ecall <= EXEcall;
        M1InstrAccessFault <= EXInstrAccessFault;
        M1InstrFault <= EXInstrFault;
        M1InstrPageFault <= EXInstrPageFault;
        M1IsCSR <= EXIsCSR;
        M1IsInstr <= EXIsInstr;
        M1PredTaken <= EXPredTaken;
        M1RegWr <= EXRegWr;
        M1Ret <= EXRet;
        M1RetType <= EXRetType;
        M1MemCtr <= EXMemCtr;
        M1RegSrc <= EXRegSrc;
        M1BranchCtr <= EXBranchCtr;
        M1Rd <= EXRd;
        M1CSRRd <= EXCSRRd;
        M1BusA <= EXBusA;
        M1BusB <= EXBusB;
        M1BusW <= EXBusW;
        M1CSRin <= EXCSRin;
        M1CSRout <= EXCSRout;
        M1imm <= EXimm;
        M1Instr <= EXInstr;
        M1PC <= EXPC;
        M1PCCtrPC1 <= EXPCCtrPC1;
        M1PCPlus4 <= EXPCPlus4;
    end
end

assign OperA = EXALUASrc == 2'h0 ? EXBusA :
               EXALUASrc == 2'h1 ? EXPC :
               EXALUASrc == 2'h2 ? EXimm :
               32'h0;
assign OperB = EXALUBSrc == 2'h0 ? EXBusB :
               EXALUBSrc == 2'h1 ? EXimm :
               EXALUBSrc == 2'h2 ? EXCSRout :
               32'h0;
assign EXRawCSRin = EXCSRSrc == 2'h0 ? EXBusW :
                    EXCSRSrc == 2'h1 ? EXBusA :
                    EXCSRSrc == 2'h2 ? EXimm :
                    32'h0;


ALU ALU (
    .ALUCtr(EXALUCtr),
    .OperA(OperA),
    .OperB(OperB),
    .ZF(EXZF),
    .CF(EXCF),
    .SF(EXSF),
    .OF(EXOF),
    .BusW(EXBusW)
);

CSROperand CSROperand (
    .CSRRd(EXCSRRd),
    .RawCSRin(EXRawCSRin),
    .CSRin(EXCSRin)
);

endmodule
