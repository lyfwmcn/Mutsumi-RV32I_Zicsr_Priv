`timescale 1ns / 1ns

module M2Stage (
    // 全局参数
    input CLK,
    input RST,
    input Flush,
    input MIE,
    input MPIE,
    input SIE,
    input SPIE,
    input SPP,
    input [1:0] MPP,
    input [1:0] Privilege,
    input [31:0] medeleg,
    input [31:0] mepc,
    input [31:0] mideleg,
    input [31:0] mie,
    input [31:0] mip,
    input [31:0] sepc,
    output ActualJump,
    output MemWait,
    output NextMIE,
    output NextMPIE,
    output NextSIE,
    output NextSPIE,
    output NextSPP,
    output PredJump,
    output PrivilegeChange,
    output Ret,
    output RetType,
    output Trap,
    output TrapType,
    output [1:0] NextMPP,
    output [1:0] NextPrivilege,
    output [31:0] Nextmcause,
    output [31:0] Nextmepc,
    output [31:0] Nextmtval,
    output [31:0] Nextscause,
    output [31:0] Nextsepc,
    output [31:0] Nextstval,

    // 外部通信参数
    input Respond_Fault_Data,
    input Respond_Valid_Data,
    input [31:0] Respond_Data_Data,

    // 旁路参数
    input IDPredTaken,
    input M2InstrAlignFault,
    input [4:0] IDBranchCtr,
    input [31:0] IDimm,
    input [31:0] IDPC,
    input [31:0] M2PCCtrPC2,
    output M2PCCtr,
    output [31:0] M2ObjAddr,
    output [31:0] M2Offset,

    // 流水线参数
    input M2ZF,
    input M2CF,
    input M2SF,
    input M2OF,
    input M2CSRWr,
    input M2DataREN,
    input M2DataWEN,
    input M2Ebreak,
    input M2Ecall,
    input M2InstrAccessFault,
    input M2InstrFault,
    input M2InstrPageFault,
    input M2IsCSR,
    input M2IsInstr,
    input M2LoadAlignFault,
    input M2PredTaken,
    input M2RegWr,
    input M2Ret,
    input M2RetType,
    input M2StoreAlignFault,
    input [2:0] M2MemCtr,
    input [2:0] M2RegSrc,
    input [4:0] M2BranchCtr,
    input [4:0] M2Rd,
    input [11:0] M2CSRRd,
    input [31:0] M2BusA,
    input [31:0] M2BusB,
    input [31:0] M2BusW,
    input [31:0] M2CSRin,
    input [31:0] M2CSRout,
    input [31:0] M2imm,
    input [31:0] M2Instr,
    input [31:0] M2PC,
    input [31:0] M2PCCtrPC1,
    input [31:0] M2PCPlus4,
    output reg WBCSRWr,
    output reg WBIsCSR,
    output reg WBIsInstr,
    output reg WBRegWr,
    output reg [2:0] WBRegSrc,
    output reg [4:0] WBRd,
    output reg [11:0] WBCSRRd,
    output reg [31:0] WBBusW,
    output reg [31:0] WBCSRin,
    output reg [31:0] WBCSRout,
    output reg [31:0] WBimm,
    output reg [31:0] WBmem,
    output reg [31:0] WBPCPlus4
);

reg [31:0] WBnextPC;

assign MemWait = (M2DataREN || M2DataWEN) && !Respond_Valid_Data;
assign Ret = M2Ret;
assign RetType = M2RetType;

wire [31:0] Data8S [3:0];
assign Data8S[0] = {{24{Respond_Data_Data[7]}}, Respond_Data_Data[7:0]};
assign Data8S[1] = {{24{Respond_Data_Data[15]}}, Respond_Data_Data[15:8]};
assign Data8S[2] = {{24{Respond_Data_Data[23]}}, Respond_Data_Data[23:16]};
assign Data8S[3] = {{24{Respond_Data_Data[31]}}, Respond_Data_Data[31:24]};

wire [31:0] Data16S [1:0];
assign Data16S[0] = {{16{Respond_Data_Data[15]}}, Respond_Data_Data[15:0]};
assign Data16S[1] = {{16{Respond_Data_Data[31]}}, Respond_Data_Data[31:16]};

wire [31:0] Data32;
assign Data32 = Respond_Data_Data;

wire [31:0] Data8U [3:0];
assign Data8U[0] = {24'h0, Respond_Data_Data[7:0]};
assign Data8U[1] = {24'h0, Respond_Data_Data[15:8]};
assign Data8U[2] = {24'h0, Respond_Data_Data[23:16]};
assign Data8U[3] = {24'h0, Respond_Data_Data[31:24]};

wire [31:0] Data16U [1:0];
assign Data16U[0] = {16'h0, Respond_Data_Data[15:0]};
assign Data16U[1] = {16'h0, Respond_Data_Data[31:16]};

wire [31:0] M2mem;
assign M2mem = !Respond_Valid_Data || Respond_Fault_Data ? 32'h0 :
               M2MemCtr == 3'h0 ? Data8S[M2BusW[1:0]] :
               M2MemCtr == 3'h1 ? Data16S[M2BusW[1]] :
               M2MemCtr == 3'h2 ? Data32 :
               M2MemCtr == 3'h4 ? Data8U[M2BusW[1:0]] :
               M2MemCtr == 3'h5 ? Data16U[M2BusW[1]] :
               32'h0;

wire M2LoadAccessFault;
wire M2LoadPageFault;
wire M2StoreAccessFault;
wire M2StorePageFault;

assign M2LoadAccessFault = M2DataREN && Respond_Valid_Data && Respond_Fault_Data;
assign M2StoreAccessFault = M2DataWEN && Respond_Valid_Data && Respond_Fault_Data;
assign M2LoadPageFault = 1'h0;
assign M2StorePageFault = 1'h0;

wire [31:0] M2nextPC;

BU BU (
    .M2ZF(M2ZF),
    .M2CF(M2CF),
    .M2SF(M2SF),
    .M2OF(M2OF),
    .IDPredTaken(IDPredTaken),
    .M2PredTaken(M2PredTaken),
    .IDBranchCtr(IDBranchCtr),
    .M2BranchCtr(M2BranchCtr),
    .IDimm(IDimm),
    .IDPC(IDPC),
    .M2BusA(M2BusA),
    .M2imm(M2imm),
    .M2PC(M2PC),
    .M2PCCtrPC1(M2PCCtrPC1),
    .M2PCCtrPC2(M2PCCtrPC2),
    .M2PCPlus4(M2PCPlus4),
    .ActualJump(ActualJump),
    .M2PCCtr(M2PCCtr),
    .PredJump(PredJump),
    .M2nextPC(M2nextPC),
    .M2ObjAddr(M2ObjAddr),
    .M2Offset(M2Offset)
);

TrapUnit TrapUnit (
    .M2Ebreak(M2Ebreak),
    .M2Ecall(M2Ecall),
    .M2InstrAccessFault(M2InstrAccessFault),
    .M2InstrAlignFault(M2InstrAlignFault),
    .M2InstrFault(M2InstrFault),
    .M2InstrPageFault(M2InstrPageFault),
    .M2LoadAccessFault(M2LoadAccessFault),
    .M2LoadAlignFault(M2LoadAlignFault),
    .M2LoadPageFault(M2LoadPageFault),
    .M2StoreAccessFault(M2StoreAccessFault),
    .M2StoreAlignFault(M2StoreAlignFault),
    .M2StorePageFault(M2StorePageFault),
    .MIE(MIE),
    .MPIE(MPIE),
    .Ret(Ret),
    .RetType(RetType),
    .SIE(SIE),
    .SPIE(SPIE),
    .SPP(SPP),
    .MPP(MPP),
    .Privilege(Privilege),
    .M2BusW(M2BusW),
    .M2Instr(M2Instr),
    .M2PC(M2PC),
    .M2PCCtrPC2(M2PCCtrPC2),
    .medeleg(medeleg),
    .mideleg(mideleg),
    .mie(mie),
    .mip(mip),
    .WBnextPC(WBnextPC),
    .NextMIE(NextMIE),
    .NextMPIE(NextMPIE),
    .NextSIE(NextSIE),
    .NextSPIE(NextSPIE),
    .PrivilegeChange(PrivilegeChange),
    .Trap(Trap),
    .TrapType(TrapType),
    .NextMPP(NextMPP),
    .NextPrivilege(NextPrivilege),
    .Nextmcause(Nextmcause),
    .Nextmepc(Nextmepc),
    .Nextmtval(Nextmtval),
    .Nextscause(Nextscause),
    .Nextsepc(Nextsepc),
    .Nextstval(Nextstval)
);

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        WBCSRWr <= 1'h0;
        WBIsCSR <= 1'h0;
        WBIsInstr <= 1'h0;
        WBRegWr <= 1'h1;
        WBRegSrc <= 3'h0;
        WBRd <= 5'h0;
        WBCSRRd <= 12'h0;
        WBBusW <= 32'h0;
        WBCSRin <= 32'h0;
        WBCSRout <= 32'h0;
        WBimm <= 32'h0;
        WBnextPC <= 32'h0;
        WBmem <= 32'h0;
        WBPCPlus4 <= 32'h4;
    end
    else if (Flush) begin
        WBCSRWr <= 1'h0;
        WBIsCSR <= 1'h0;
        WBIsInstr <= 1'h0;
        WBRegWr <= 1'h1;
        WBRegSrc <= 3'h0;
        WBRd <= 5'h0;
        WBCSRRd <= 12'h0;
        WBBusW <= 32'h0;
        WBCSRin <= 32'h0;
        WBCSRout <= 32'h0;
        WBimm <= 32'h0;
        WBmem <= 32'h0;
        WBPCPlus4 <= 32'h4;
    end
    else begin
        WBCSRWr <= M2CSRWr;
        WBIsCSR <= M2IsCSR;
        WBIsInstr <= M2IsInstr;
        WBRegWr <= M2RegWr;
        WBRegSrc <= M2RegSrc;
        WBRd <= M2Rd;
        WBCSRRd <= M2CSRRd;
        WBBusW <= M2BusW;
        WBCSRin <= M2CSRin;
        WBCSRout <= M2CSRout;
        WBimm <= M2imm;
        WBnextPC <= !M2IsInstr ? WBnextPC :
                    Ret ? (RetType ? {sepc[31:2], 2'h0} : {mepc[31:2], 2'h0}) :
                    M2nextPC;
        WBmem <= M2mem;
        WBPCPlus4 <= M2PCPlus4;
    end
end

endmodule
