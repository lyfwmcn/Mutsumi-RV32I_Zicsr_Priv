`timescale 1ns / 1ns

module IDStage (
    // 全局参数
    input CLK,
    input RST,
    input Flush,
    input Stall,
    input [1:0] Privilege,

    // 旁路参数
    input [31:0] IDBusA,
    input [31:0] IDBusB,
    input [31:0] IDCSRout,
    input [31:0] IDPCCtrPC1,
    output IDBusAused,
    output IDBusBused,
    output IDCSRWr,
    output IDIsCSR,
    output IDPredTaken,
    output [4:0] IDBranchCtr,
    output [4:0] IDRs1,
    output [4:0] IDRs2,
    output [11:0] IDCSRRd,
    output [31:0] IDimm,

    // 流水线参数
    input IDInstrAccessFault,
    input IDInstrPageFault,
    input IDIsInstr,
    input [31:0] IDInstr,
    input [31:0] IDPC,
    input [31:0] IDPCPlus4,
    output reg EXCSRWr,
    output reg EXDataREN,
    output reg EXDataWEN,
    output reg EXEbreak,
    output reg EXEcall,
    output reg EXInstrAccessFault,
    output reg EXInstrFault,
    output reg EXInstrPageFault,
    output reg EXIsCSR,
    output reg EXIsInstr,
    output reg EXPredTaken,
    output reg EXRegWr,
    output reg EXRet,
    output reg EXRetType,
    output reg [1:0] EXALUASrc,
    output reg [1:0] EXALUBSrc,
    output reg [1:0] EXCSRSrc,
    output reg [2:0] EXMemCtr,
    output reg [2:0] EXRegSrc,
    output reg [4:0] EXBranchCtr,
    output reg [4:0] EXRd,
    output reg [5:0] EXALUCtr,
    output reg [11:0] EXCSRRd,
    output reg [31:0] EXBusA,
    output reg [31:0] EXBusB,
    output reg [31:0] EXCSRout,
    output reg [31:0] EXimm,
    output reg [31:0] EXInstr,
    output reg [31:0] EXPC,
    output reg [31:0] EXPCCtrPC1,
    output reg [31:0] EXPCPlus4
);

wire IDDataREN;
wire IDDataWEN;
wire IDEbreak;
wire IDEcall;
wire IDInstrFault;
wire IDRegWr;
wire IDRet;
wire IDRetType;
wire [1:0] IDALUASrc;
wire [1:0] IDALUBSrc;
wire [1:0] IDCSRSrc;
wire [2:0] IDMemCtr;
wire [2:0] IDRegSrc;
wire [4:0] IDRd;
wire [5:0] IDALUCtr;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        EXCSRWr <= 1'h0;
        EXDataREN <= 1'h0;
        EXDataWEN <= 1'h0;
        EXEbreak <= 1'h0;
        EXEcall <= 1'h0;
        EXInstrAccessFault <= 1'h0;
        EXInstrFault <= 1'h0;
        EXInstrPageFault <= 1'h0;
        EXIsCSR <= 1'h0;
        EXIsInstr <= 1'h0;
        EXPredTaken <= 1'h0;
        EXRegWr <= 1'h1;
        EXRet <= 1'h0;
        EXRetType <= 1'h0;
        EXALUASrc <= 2'h0;
        EXALUBSrc <= 2'h1;
        EXCSRSrc <= 2'h0;
        EXMemCtr <= 3'h2;
        EXRegSrc <= 3'h0;
        EXBranchCtr <= 5'h0;
        EXRd <= 5'h0;
        EXALUCtr <= 6'h0;
        EXCSRRd <= 12'h0;
        EXBusA <= 32'h0;
        EXBusB <= 32'h0;
        EXCSRout <= 32'h0;
        EXimm <= 32'h0;
        EXInstr <= 32'h13;
        EXPC <= 32'h0;
        EXPCCtrPC1 <= 32'h4;
        EXPCPlus4 <= 32'h4;
    end
    else if (Flush) begin
        EXCSRWr <= 1'h0;
        EXDataREN <= 1'h0;
        EXDataWEN <= 1'h0;
        EXEbreak <= 1'h0;
        EXEcall <= 1'h0;
        EXInstrAccessFault <= 1'h0;
        EXInstrFault <= 1'h0;
        EXInstrPageFault <= 1'h0;
        EXIsCSR <= 1'h0;
        EXIsInstr <= 1'h0;
        EXPredTaken <= 1'h0;
        EXRegWr <= 1'h1;
        EXRet <= 1'h0;
        EXRetType <= 1'h0;
        EXALUASrc <= 2'h0;
        EXALUBSrc <= 2'h1;
        EXCSRSrc <= 2'h0;
        EXMemCtr <= 3'h2;
        EXRegSrc <= 3'h0;
        EXBranchCtr <= 5'h0;
        EXRd <= 5'h0;
        EXALUCtr <= 6'h0;
        EXCSRRd <= 12'h0;
        EXBusA <= 32'h0;
        EXBusB <= 32'h0;
        EXCSRout <= 32'h0;
        EXimm <= 32'h0;
        EXInstr <= 32'h13;
        EXPC <= 32'h0;
        EXPCCtrPC1 <= 32'h4;
        EXPCPlus4 <= 32'h4;
    end
    else if (!Stall) begin
        EXCSRWr <= IDCSRWr;
        EXDataREN <= IDDataREN;
        EXDataWEN <= IDDataWEN;
        EXEbreak <= IDEbreak;
        EXEcall <= IDEcall;
        EXInstrAccessFault <= IDInstrAccessFault;
        EXInstrFault <= IDInstrFault;
        EXInstrPageFault <= IDInstrPageFault;
        EXIsCSR <= IDIsCSR;
        EXIsInstr <= IDIsInstr;
        EXPredTaken <= IDPredTaken;
        EXRegWr <= IDRegWr;
        EXRet <= IDRet;
        EXRetType <= IDRetType;
        EXALUASrc <= IDALUASrc;
        EXALUBSrc <= IDALUBSrc;
        EXCSRSrc <= IDCSRSrc;
        EXMemCtr <= IDMemCtr;
        EXRegSrc <= IDRegSrc;
        EXBranchCtr <= IDBranchCtr;
        EXRd <= IDRd;
        EXALUCtr <= IDALUCtr;
        EXCSRRd <= IDCSRRd;
        EXBusA <= IDBusA;
        EXBusB <= IDBusB;
        EXCSRout <= IDCSRout;
        EXimm <= IDimm;
        EXInstr <= IDInstr;
        EXPC <= IDPC;
        EXPCCtrPC1 <= IDPCCtrPC1;
        EXPCPlus4 <= IDPCPlus4;
    end
end

IDU IDU (
    .Privilege(Privilege),
    .Instr(IDInstr),
    .BusAused(IDBusAused),
    .BusBused(IDBusBused),
    .CSRWr(IDCSRWr),
    .DataREN(IDDataREN),
    .DataWEN(IDDataWEN),
    .Ebreak(IDEbreak),
    .Ecall(IDEcall),
    .InstrFault(IDInstrFault),
    .IsCSR(IDIsCSR),
    .PredTaken(IDPredTaken),
    .RegWr(IDRegWr),
    .Ret(IDRet),
    .RetType(IDRetType),
    .ALUASrc(IDALUASrc),
    .ALUBSrc(IDALUBSrc),
    .CSRSrc(IDCSRSrc),
    .MemCtr(IDMemCtr),
    .RegSrc(IDRegSrc),
    .BranchCtr(IDBranchCtr),
    .Rd(IDRd),
    .Rs1(IDRs1),
    .Rs2(IDRs2),
    .ALUCtr(IDALUCtr),
    .CSRRd(IDCSRRd),
    .imm(IDimm)
);

endmodule
