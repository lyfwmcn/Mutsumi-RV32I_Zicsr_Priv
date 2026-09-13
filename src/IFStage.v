`timescale 1ns / 1ns

module IFStage (
    // 全局参数
    input CLK,
    input RST,
    input Flush,
    input Ret,
    input RetType,
    input Stall,
    input Trap,
    input TrapType,
    input [31:0] mepc,
    input [31:0] mtvec,
    input [31:0] sepc,
    input [31:0] stvec,

    // 外部通信参数
    input Respond_Fault_Instr,
    input Respond_Valid_Instr,
    input [31:0] Respond_Data_Instr,
    output Request_Valid_Instr,
    output [31:0] Request_Addr_Instr,

    // 旁路参数
    input M2PCCtr,
    input [31:0] M2ObjAddr,
    input [31:0] M2Offset,
    output M2InstrAlignFault,
    output [31:0] IDPCCtrPC1,
    output [31:0] M2PCCtrPC2,

    // 流水线参数
    output IDInstrAccessFault,
    output IDInstrPageFault,
    output IDIsInstr,
    output [31:0] IDInstr,
    output [31:0] IDPC,
    output [31:0] IDPCPlus4
);

wire Full;
wire Empty;
assign Request_Valid_Instr = !Stall && !Flush && !Full;

assign IDInstrPageFault = 1'h0;
assign IDIsInstr = !Empty && !IDInstrAccessFault && !IDInstrPageFault;
assign IDPCPlus4 = IDPC + 32'h4;

assign IDPCCtrPC1 = M2PCCtrPC2;

PCReg PCReg (
    .CLK(CLK),
    .RST(RST),
    .PCCtr(M2PCCtr),
    .Stall(Stall || Full),
    .Ret(Ret),
    .RetType(RetType),
    .Trap(Trap),
    .TrapType(TrapType),
    .mepc(mepc),
    .mtvec(mtvec),
    .ObjAddr(M2ObjAddr),
    .Offset(M2Offset),
    .sepc(sepc),
    .stvec(stvec),
    .InstrAlignFault(M2InstrAlignFault),
    .PC(Request_Addr_Instr),
    .PCCtrPC(M2PCCtrPC2)
);

InstrBufferUnit InstrBufferUnit (
    .CLK(CLK),
    .RST(RST),
    .Flush(Flush),
    .Request_Valid_Instr(Request_Valid_Instr),
    .Respond_Fault_Instr(Respond_Fault_Instr),
    .Respond_Valid_Instr(Respond_Valid_Instr),
    .Stall(Stall),
    .Request_Addr_Instr(Request_Addr_Instr),
    .Respond_Data_Instr(Respond_Data_Instr),
    .Empty(Empty),
    .Full(Full),
    .InstrFault(IDInstrAccessFault),
    .Instr(IDInstr),
    .PC(IDPC)
);

endmodule
