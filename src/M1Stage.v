`timescale 1ns / 1ns

module M1Stage (
    // 全局参数
    input CLK,
    input RST,
    input Flush,
    input Stall,

    // 外部通信参数
    output Request_Valid_Data,
    output Request_Write_Data,
    output [3:0] Request_EN_Data,
    output [31:0] Request_Addr_Data,
    output [31:0] Request_Data_Data,

    // 流水线参数
    input M1ZF,
    input M1CF,
    input M1SF,
    input M1OF,
    input M1CSRWr,
    input M1DataREN,
    input M1DataWEN,
    input M1Ebreak,
    input M1Ecall,
    input M1InstrAccessFault,
    input M1InstrFault,
    input M1InstrPageFault,
    input M1IsCSR,
    input M1IsInstr,
    input M1PredTaken,
    input M1RegWr,
    input M1Ret,
    input M1RetType,
    input [2:0] M1MemCtr,
    input [2:0] M1RegSrc,
    input [4:0] M1BranchCtr,
    input [4:0] M1Rd,
    input [11:0] M1CSRRd,
    input [31:0] M1BusA,
    input [31:0] M1BusB,
    input [31:0] M1BusW,
    input [31:0] M1CSRin,
    input [31:0] M1CSRout,
    input [31:0] M1imm,
    input [31:0] M1Instr,
    input [31:0] M1PC,
    input [31:0] M1PCCtrPC1,
    input [31:0] M1PCPlus4,
    output reg M2ZF,
    output reg M2CF,
    output reg M2SF,
    output reg M2OF,
    output reg M2CSRWr,
    output reg M2DataREN,
    output reg M2DataWEN,
    output reg M2Ebreak,
    output reg M2Ecall,
    output reg M2InstrAccessFault,
    output reg M2InstrFault,
    output reg M2InstrPageFault,
    output reg M2IsCSR,
    output reg M2IsInstr,
    output reg M2LoadAlignFault,
    output reg M2PredTaken,
    output reg M2RegWr,
    output reg M2Ret,
    output reg M2RetType,
    output reg M2StoreAlignFault,
    output reg [2:0] M2MemCtr,
    output reg [2:0] M2RegSrc,
    output reg [4:0] M2BranchCtr,
    output reg [4:0] M2Rd,
    output reg [11:0] M2CSRRd,
    output reg [31:0] M2BusA,
    output reg [31:0] M2BusB,
    output reg [31:0] M2BusW,
    output reg [31:0] M2CSRin,
    output reg [31:0] M2CSRout,
    output reg [31:0] M2imm,
    output reg [31:0] M2Instr,
    output reg [31:0] M2PC,
    output reg [31:0] M2PCCtrPC1,
    output reg [31:0] M2PCPlus4
);

wire M1LoadAlignFault;
wire M1StoreAlignFault;
assign M1LoadAlignFault = M1DataREN == 1'h1 && (((M1MemCtr == 3'h1 || M1MemCtr == 3'h5) && M1BusW[0] != 1'h0) || (M1MemCtr == 3'h2 && M1BusW[1:0] != 2'h0));
assign M1StoreAlignFault = M1DataWEN == 1'h1 && ((M1MemCtr == 3'h1 && M1BusW[0] != 1'h0) || (M1MemCtr == 3'h2 && M1BusW[1:0] != 2'h0));

assign Request_Valid_Data = !Flush && !Stall && ((M1DataREN && !M1LoadAlignFault) || (M1DataWEN && !M1StoreAlignFault));
assign Request_Write_Data = M1DataWEN;
wire [3:0] MEN0 [3:0];
assign MEN0[0] = 4'h1;
assign MEN0[1] = 4'h2;
assign MEN0[2] = 4'h4;
assign MEN0[3] = 4'h8;
wire [3:0] MEN1 [1:0];
assign MEN1[0] = 4'h3;
assign MEN1[1] = 4'hc;
wire [3:0] MEN2;
assign MEN2 = 4'hf;
assign Request_EN_Data = M1MemCtr[1:0] == 2'h0 ? MEN0[M1BusW[1:0]] :
                         M1MemCtr[1:0] == 2'h1 ? MEN1[M1BusW[1]] :
                         M1MemCtr[1:0] == 2'h2 ? MEN2 :
                         4'h0;
assign Request_Addr_Data = {M1BusW[31:2], 2'h0};
wire [31:0] MData0 [3:0];
assign MData0[0] = {24'h0, M1BusB[7:0]};
assign MData0[1] = {16'h0, M1BusB[7:0], 8'h0};
assign MData0[2] = {8'h0, M1BusB[7:0], 16'h0};
assign MData0[3] = {M1BusB[7:0], 24'h0};
wire [31:0] MData1 [1:0];
assign MData1[0] = {16'h0, M1BusB[15:0]};
assign MData1[1] = {M1BusB[15:0], 16'h0};
wire [31:0] MData2;
assign MData2 = M1BusB;
assign Request_Data_Data = !M1DataWEN ? 32'h0 :
                           M1MemCtr == 3'h0 ? MData0[M1BusW[1:0]] :
                           M1MemCtr == 3'h1 ? MData1[M1BusW[1]] :
                           M1MemCtr == 3'h2 ? MData2 :
                           32'h0;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        M2ZF <= 1'h1;
        M2CF <= 1'h0;
        M2SF <= 1'h0;
        M2OF <= 1'h0;
        M2CSRWr <= 1'h0;
        M2DataREN <= 1'h0;
        M2DataWEN <= 1'h0;
        M2Ebreak <= 1'h0;
        M2Ecall <= 1'h0;
        M2InstrAccessFault <= 1'h0;
        M2InstrFault <= 1'h0;
        M2InstrPageFault <= 1'h0;
        M2IsCSR <= 1'h0;
        M2IsInstr <= 1'h0;
        M2LoadAlignFault <= 1'h0;
        M2PredTaken <= 1'h0;
        M2RegWr <= 1'h1;
        M2Ret <= 1'h0;
        M2RetType <= 1'h0;
        M2StoreAlignFault <= 1'h0;
        M2MemCtr <= 3'h2;
        M2RegSrc <= 3'h0;
        M2BranchCtr <= 5'h0;
        M2Rd <= 5'h0;
        M2CSRRd <= 12'h0;
        M2BusA <= 32'h0;
        M2BusB <= 32'h0;
        M2BusW <= 32'h0;
        M2CSRin <= 32'h0;
        M2CSRout <= 32'h0;
        M2imm <= 32'h0;
        M2Instr <= 32'h13;
        M2PC <= 32'h0;
        M2PCCtrPC1 <= 32'h4;
        M2PCPlus4 <= 32'h4;
    end
    else if (Flush) begin
        M2ZF <= 1'h1;
        M2CF <= 1'h0;
        M2SF <= 1'h0;
        M2OF <= 1'h0;
        M2CSRWr <= 1'h0;
        M2DataREN <= 1'h0;
        M2DataWEN <= 1'h0;
        M2Ebreak <= 1'h0;
        M2Ecall <= 1'h0;
        M2InstrAccessFault <= 1'h0;
        M2InstrFault <= 1'h0;
        M2InstrPageFault <= 1'h0;
        M2IsCSR <= 1'h0;
        M2IsInstr <= 1'h0;
        M2LoadAlignFault <= 1'h0;
        M2PredTaken <= 1'h0;
        M2RegWr <= 1'h1;
        M2Ret <= 1'h0;
        M2RetType <= 1'h0;
        M2StoreAlignFault <= 1'h0;
        M2MemCtr <= 3'h2;
        M2RegSrc <= 3'h0;
        M2BranchCtr <= 5'h0;
        M2Rd <= 5'h0;
        M2CSRRd <= 12'h0;
        M2BusA <= 32'h0;
        M2BusB <= 32'h0;
        M2BusW <= 32'h0;
        M2CSRin <= 32'h0;
        M2CSRout <= 32'h0;
        M2imm <= 32'h0;
        M2Instr <= 32'h13;
        M2PC <= 32'h0;
        M2PCCtrPC1 <= 32'h4;
        M2PCPlus4 <= 32'h4;
    end
    else if (!Stall) begin
        M2ZF <= M1ZF;
        M2CF <= M1CF;
        M2SF <= M1SF;
        M2OF <= M1OF;
        M2CSRWr <= M1CSRWr;
        M2DataREN <= M1DataREN;
        M2DataWEN <= M1DataWEN;
        M2Ebreak <= M1Ebreak;
        M2Ecall <= M1Ecall;
        M2InstrAccessFault <= M1InstrAccessFault;
        M2InstrFault <= M1InstrFault;
        M2InstrPageFault <= M1InstrPageFault;
        M2IsCSR <= M1IsCSR;
        M2IsInstr <= M1IsInstr;
        M2LoadAlignFault <= M1LoadAlignFault;
        M2PredTaken <= M1PredTaken;
        M2RegWr <= M1RegWr;
        M2Ret <= M1Ret;
        M2RetType <= M1RetType;
        M2StoreAlignFault <= M1StoreAlignFault;
        M2MemCtr <= M1MemCtr;
        M2RegSrc <= M1RegSrc;
        M2BranchCtr <= M1BranchCtr;
        M2Rd <= M1Rd;
        M2CSRRd <= M1CSRRd;
        M2BusA <= M1BusA;
        M2BusB <= M1BusB;
        M2BusW <= M1BusW;
        M2CSRin <= M1CSRin;
        M2CSRout <= M1CSRout;
        M2imm <= M1imm;
        M2Instr <= M1Instr;
        M2PC <= M1PC;
        M2PCCtrPC1 <= M1PCCtrPC1;
        M2PCPlus4 <= M1PCPlus4;
    end
end

endmodule
