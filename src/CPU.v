`timescale 1ns / 1ns

module CPU (
    input CLK,
    input RST,

    input External_Interrupt_Clear,
    input External_Interrupt_Set,
    input Timer_Interrupt_Clear,
    input Timer_Interrupt_Set,

    input Respond_Fault_Data,
    input Respond_Fault_Instr,
    input Respond_Valid_Data,
    input Respond_Valid_Instr,
    input [31:0] Respond_Data_Data,
    input [31:0] Respond_Data_Instr,
    output Request_Valid_Data,
    output Request_Valid_Instr,
    output Request_Write_Data,
    output [3:0] Request_EN_Data,
    output [31:0] Request_Addr_Data,
    output [31:0] Request_Addr_Instr,
    output [31:0] Request_Data_Data
);

// 全局变量
wire ActualJump;
wire CSRWait;
wire MemWait;
wire PredJump;
wire PrivilegeChange;
wire RegWait;
wire Ret;
wire RetType;
wire Trap;
wire TrapType;

wire MIE;
wire MPIE;
wire NextMIE;
wire NextMPIE;
wire NextSIE;
wire NextSPIE;
wire NextSPP;
wire SIE;
wire SPIE;
wire SPP;
wire [1:0] MPP;
wire [1:0] NextMPP;
wire [1:0] NextPrivilege;
wire [1:0] Privilege;
wire [31:0] medeleg;
wire [31:0] mepc;
wire [31:0] mideleg;
wire [31:0] mie;
wire [31:0] mip;
wire [31:0] mtvec;
wire [31:0] sepc;
wire [31:0] stvec;
wire [31:0] Nextmcause;
wire [31:0] Nextmepc;
wire [31:0] Nextmtval;
wire [31:0] Nextscause;
wire [31:0] Nextsepc;
wire [31:0] Nextstval;

// 流水线、旁路变量
// IF -> ID
wire IDInstrAccessFault;
wire IDInstrPageFault;
wire IDIsInstr;
wire [31:0] IDInstr;
wire [31:0] IDPC;
wire [31:0] IDPCPlus4;
// -> ID
wire [31:0] IDBusA;
wire [31:0] IDBusB;
wire [31:0] IDCSRout;
wire [31:0] IDPCCtrPC1;
// ID ->
wire IDBusAused;
wire IDBusBused;
wire IDCSRWr;
wire IDIsCSR;
wire IDPredTaken;
wire [4:0] IDBranchCtr;
wire [4:0] IDRs1;
wire [4:0] IDRs2;
wire [11:0] IDCSRRd;
wire [31:0] IDimm;
// ID -> EX
wire EXCSRWr;
wire EXDataREN;
wire EXDataWEN;
wire EXEbreak;
wire EXEcall;
wire EXInstrAccessFault;
wire EXInstrFault;
wire EXInstrPageFault;
wire EXIsCSR;
wire EXIsInstr;
wire EXPredTaken;
wire EXRegWr;
wire EXRet;
wire EXRetType;
wire [1:0] EXALUASrc;
wire [1:0] EXALUBSrc;
wire [1:0] EXCSRSrc;
wire [2:0] EXMemCtr;
wire [2:0] EXRegSrc;
wire [4:0] EXBranchCtr;
wire [4:0] EXRd;
wire [5:0] EXALUCtr;
wire [11:0] EXCSRRd;
wire [31:0] EXBusA;
wire [31:0] EXBusB;
wire [31:0] EXCSRout;
wire [31:0] EXimm;
wire [31:0] EXInstr;
wire [31:0] EXPC;
wire [31:0] EXPCCtrPC1;
wire [31:0] EXPCPlus4;
// IF -> M2
wire M2PCCtr;
wire [31:0] M2ObjAddr;
wire [31:0] M2Offset;
wire M2InstrAlignFault;
wire [31:0] M2PCCtrPC2;
// EX ->
wire [31:0] EXBusW;
// EX -> M1
wire M1ZF;
wire M1CF;
wire M1SF;
wire M1OF;
wire M1CSRWr;
wire M1DataREN;
wire M1DataWEN;
wire M1Ebreak;
wire M1Ecall;
wire M1InstrAccessFault;
wire M1InstrFault;
wire M1InstrPageFault;
wire M1IsCSR;
wire M1IsInstr;
wire M1PredTaken;
wire M1RegWr;
wire M1Ret;
wire M1RetType;
wire [2:0] M1MemCtr;
wire [2:0] M1RegSrc;
wire [4:0] M1BranchCtr;
wire [4:0] M1Rd;
wire [11:0] M1CSRRd;
wire [31:0] M1BusA;
wire [31:0] M1BusB;
wire [31:0] M1BusW;
wire [31:0] M1CSRin;
wire [31:0] M1CSRout;
wire [31:0] M1imm;
wire [31:0] M1Instr;
wire [31:0] M1PC;
wire [31:0] M1PCCtrPC1;
wire [31:0] M1PCPlus4;
// M1 -> M2
wire M2ZF;
wire M2CF;
wire M2SF;
wire M2OF;
wire M2CSRWr;
wire M2DataREN;
wire M2DataWEN;
wire M2Ebreak;
wire M2Ecall;
wire M2InstrAccessFault;
wire M2InstrFault;
wire M2InstrPageFault;
wire M2IsCSR;
wire M2IsInstr;
wire M2LoadAlignFault;
wire M2PredTaken;
wire M2RegWr;
wire M2Ret;
wire M2RetType;
wire M2StoreAlignFault;
wire [2:0] M2MemCtr;
wire [2:0] M2RegSrc;
wire [4:0] M2BranchCtr;
wire [4:0] M2Rd;
wire [11:0] M2CSRRd;
wire [31:0] M2BusA;
wire [31:0] M2BusB;
wire [31:0] M2BusW;
wire [31:0] M2CSRin;
wire [31:0] M2CSRout;
wire [31:0] M2imm;
wire [31:0] M2Instr;
wire [31:0] M2PC;
wire [31:0] M2PCCtrPC1;
wire [31:0] M2PCPlus4;
// M2 -> WB
wire WBCSRWr;
wire WBIsCSR;
wire WBIsInstr;
wire WBRegWr;
wire [2:0] WBRegSrc;
wire [4:0] WBRd;
wire [11:0] WBCSRRd;
wire [31:0] WBBusW;
wire [31:0] WBCSRin;
wire [31:0] WBCSRout;
wire [31:0] WBimm;
wire [31:0] WBmem;
wire [31:0] WBPCPlus4;

// 存储全局参数
wire CurMIE;
wire CurMPIE;
wire CurSIE;
wire CurSPIE;
wire CurSPP;
wire [1:0] CurMPP;
wire [31:0] Curmedeleg;
wire [31:0] Curmepc;
wire [31:0] Curmideleg;
wire [31:0] Curmie;
wire [31:0] Curmip;
wire [31:0] Curmtvec;
wire [31:0] Cursepc;
wire [31:0] Curstvec;
wire [31:0] Regin;
wire [31:0] RegoutA;
wire [31:0] RegoutB;

PrivilegeMode PrivilegeMode (
    .CLK(CLK),
    .RST(RST),
    .PrivilegeChange(PrivilegeChange),
    .NextPrivilege(NextPrivilege),
    .Privilege(Privilege)
);

RegFile RegFile (
    .CLK(CLK),
    .RST(RST),
    .RegWr(WBRegWr),
    .Rd(WBRd),
    .Rs1(IDRs1),
    .Rs2(IDRs2),
    .Regin(Regin),
    .RegoutA(RegoutA),
    .RegoutB(RegoutB)
);

CSRFile CSRFile (
    .CLK(CLK),
    .RST(RST),
    .External_Interrupt_Clear(External_Interrupt_Clear),
    .External_Interrupt_Set(External_Interrupt_Set),
    .Timer_Interrupt_Clear(Timer_Interrupt_Clear),
    .Timer_Interrupt_Set(Timer_Interrupt_Set),
    .CSRWr(WBCSRWr),
    .NextMIE(NextMIE),
    .NextMPIE(NextMPIE),
    .NextSIE(NextSIE),
    .NextSPIE(NextSPIE),
    .NextSPP(NextSPP),
    .Ret(Ret),
    .RetType(RetType),
    .Trap(Trap),
    .TrapType(TrapType),
    .WBIsInstr(WBIsInstr),
    .NextMPP(NextMPP),
    .CSRRd(WBCSRRd),
    .CSRRs(IDCSRRd),
    .CSRin(WBCSRin),
    .Nextmcause(Nextmcause),
    .Nextmepc(Nextmepc),
    .Nextmtval(Nextmtval),
    .Nextstval(Nextstval),
    .Nextsepc(Nextsepc),
    .Nextscause(Nextscause),
    .CurMIE(CurMIE),
    .CurMPIE(CurMPIE),
    .CurSIE(CurSIE),
    .CurSPIE(CurSPIE),
    .CurSPP(CurSPP),
    .CurMPP(CurMPP),
    .CSRout(IDCSRout),
    .Curmedeleg(Curmedeleg),
    .Curmepc(Curmepc),
    .Curmideleg(Curmideleg),
    .Curmie(Curmie),
    .Curmip(Curmip),
    .Curmtvec(Curmtvec),
    .Cursepc(Cursepc),
    .Curstvec(Curstvec)
);

TrapCSRByPass TrapCSRByPass (
    .CurMIE(CurMIE),
    .CurMPIE(CurMPIE),
    .CurSIE(CurSIE),
    .CurSPIE(CurSPIE),
    .CurSPP(CurSPP),
    .WBCSRWr(WBCSRWr),
    .CurMPP(CurMPP),
    .WBCSRRd(WBCSRRd),
    .Curmedeleg(Curmedeleg),
    .Curmepc(Curmepc),
    .Curmideleg(Curmideleg),
    .Curmie(Curmie),
    .Curmip(Curmip),
    .Curmtvec(Curmtvec),
    .Cursepc(Cursepc),
    .Curstvec(Curstvec),
    .WBCSRin(WBCSRin),
    .MIE(MIE),
    .MPIE(MPIE),
    .SIE(SIE),
    .SPIE(SPIE),
    .SPP(SPP),
    .MPP(MPP),
    .medeleg(medeleg),
    .mepc(mepc),
    .mideleg(mideleg),
    .mie(mie),
    .mip(mip),
    .mtvec(mtvec),
    .sepc(sepc),
    .stvec(stvec)
);

IFStage IFStage (
    .CLK(CLK),
    .RST(RST),
    .Flush(ActualJump | (PredJump & !RegWait & !CSRWait & !MemWait) | Trap | Ret),
    .Ret(Ret),
    .RetType(RetType),
    .Stall(RegWait | CSRWait | MemWait),
    .Trap(Trap),
    .TrapType(TrapType),
    .mepc(mepc),
    .mtvec(mtvec),
    .sepc(sepc),
    .stvec(stvec),

    .Respond_Fault_Instr(Respond_Fault_Instr),
    .Respond_Valid_Instr(Respond_Valid_Instr),
    .Respond_Data_Instr(Respond_Data_Instr),
    .Request_Valid_Instr(Request_Valid_Instr),
    .Request_Addr_Instr(Request_Addr_Instr),

    .M2PCCtr(M2PCCtr),
    .M2ObjAddr(M2ObjAddr),
    .M2Offset(M2Offset),
    .M2InstrAlignFault(M2InstrAlignFault),
    .IDPCCtrPC1(IDPCCtrPC1),
    .M2PCCtrPC2(M2PCCtrPC2),

    .IDInstrAccessFault(IDInstrAccessFault),
    .IDInstrPageFault(IDInstrPageFault),
    .IDIsInstr(IDIsInstr),
    .IDInstr(IDInstr),
    .IDPC(IDPC),
    .IDPCPlus4(IDPCPlus4)
);

IDStage IDStage (
    .CLK(CLK),
    .RST(RST),
    .Flush(((RegWait | CSRWait) & !MemWait) | ActualJump | Trap | Ret),
    .Stall(MemWait),
    .Privilege(Privilege),

    .IDBusA(IDBusA),
    .IDBusB(IDBusB),
    .IDCSRout(IDCSRout),
    .IDPCCtrPC1(IDPCCtrPC1),
    .IDBusAused(IDBusAused),
    .IDBusBused(IDBusBused),
    .IDCSRWr(IDCSRWr),
    .IDIsCSR(IDIsCSR),
    .IDPredTaken(IDPredTaken),
    .IDBranchCtr(IDBranchCtr),
    .IDRs1(IDRs1),
    .IDRs2(IDRs2),
    .IDCSRRd(IDCSRRd),
    .IDimm(IDimm),

    .IDInstrAccessFault(IDInstrAccessFault),
    .IDInstrPageFault(IDInstrPageFault),
    .IDIsInstr(IDIsInstr),
    .IDInstr(IDInstr),
    .IDPC(IDPC),
    .IDPCPlus4(IDPCPlus4),
    .EXCSRWr(EXCSRWr),
    .EXDataREN(EXDataREN),
    .EXDataWEN(EXDataWEN),
    .EXEbreak(EXEbreak),
    .EXEcall(EXEcall),
    .EXInstrAccessFault(EXInstrAccessFault),
    .EXInstrFault(EXInstrFault),
    .EXInstrPageFault(EXInstrPageFault),
    .EXIsCSR(EXIsCSR),
    .EXIsInstr(EXIsInstr),
    .EXPredTaken(EXPredTaken),
    .EXRegWr(EXRegWr),
    .EXRet(EXRet),
    .EXRetType(EXRetType),
    .EXALUASrc(EXALUASrc),
    .EXALUBSrc(EXALUBSrc),
    .EXCSRSrc(EXCSRSrc),
    .EXMemCtr(EXMemCtr),
    .EXRegSrc(EXRegSrc),
    .EXBranchCtr(EXBranchCtr),
    .EXRd(EXRd),
    .EXALUCtr(EXALUCtr),
    .EXCSRRd(EXCSRRd),
    .EXBusA(EXBusA),
    .EXBusB(EXBusB),
    .EXCSRout(EXCSRout),
    .EXimm(EXimm),
    .EXInstr(EXInstr),
    .EXPC(EXPC),
    .EXPCCtrPC1(EXPCCtrPC1),
    .EXPCPlus4(EXPCPlus4)
);

EXStage EXStage (
    .CLK(CLK),
    .RST(RST),
    .Flush(ActualJump | Trap | Ret),
    .Stall(MemWait),

    .EXBusW(EXBusW),

    .EXCSRWr(EXCSRWr),
    .EXDataREN(EXDataREN),
    .EXDataWEN(EXDataWEN),
    .EXEbreak(EXEbreak),
    .EXEcall(EXEcall),
    .EXInstrAccessFault(EXInstrAccessFault),
    .EXInstrFault(EXInstrFault),
    .EXInstrPageFault(EXInstrPageFault),
    .EXIsCSR(EXIsCSR),
    .EXIsInstr(EXIsInstr),
    .EXPredTaken(EXPredTaken),
    .EXRegWr(EXRegWr),
    .EXRet(EXRet),
    .EXRetType(EXRetType),
    .EXALUASrc(EXALUASrc),
    .EXALUBSrc(EXALUBSrc),
    .EXCSRSrc(EXCSRSrc),
    .EXMemCtr(EXMemCtr),
    .EXRegSrc(EXRegSrc),
    .EXBranchCtr(EXBranchCtr),
    .EXRd(EXRd),
    .EXALUCtr(EXALUCtr),
    .EXCSRRd(EXCSRRd),
    .EXBusA(EXBusA),
    .EXBusB(EXBusB),
    .EXCSRout(EXCSRout),
    .EXimm(EXimm),
    .EXInstr(EXInstr),
    .EXPC(EXPC),
    .EXPCCtrPC1(EXPCCtrPC1),
    .EXPCPlus4(EXPCPlus4),
    .M1ZF(M1ZF),
    .M1CF(M1CF),
    .M1SF(M1SF),
    .M1OF(M1OF),
    .M1CSRWr(M1CSRWr),
    .M1DataREN(M1DataREN),
    .M1DataWEN(M1DataWEN),
    .M1Ebreak(M1Ebreak),
    .M1Ecall(M1Ecall),
    .M1InstrAccessFault(M1InstrAccessFault),
    .M1InstrFault(M1InstrFault),
    .M1InstrPageFault(M1InstrPageFault),
    .M1IsCSR(M1IsCSR),
    .M1IsInstr(M1IsInstr),
    .M1PredTaken(M1PredTaken),
    .M1RegWr(M1RegWr),
    .M1Ret(M1Ret),
    .M1RetType(M1RetType),
    .M1MemCtr(M1MemCtr),
    .M1RegSrc(M1RegSrc),
    .M1BranchCtr(M1BranchCtr),
    .M1Rd(M1Rd),
    .M1CSRRd(M1CSRRd),
    .M1BusA(M1BusA),
    .M1BusB(M1BusB),
    .M1BusW(M1BusW),
    .M1CSRin(M1CSRin),
    .M1CSRout(M1CSRout),
    .M1imm(M1imm),
    .M1Instr(M1Instr),
    .M1PC(M1PC),
    .M1PCCtrPC1(M1PCCtrPC1),
    .M1PCPlus4(M1PCPlus4)
);

M1Stage M1Stage (
    .CLK(CLK),
    .RST(RST),
    .Flush(ActualJump | Trap | Ret),
    .Stall(MemWait),

    .Request_Valid_Data(Request_Valid_Data),
    .Request_Write_Data(Request_Write_Data),
    .Request_EN_Data(Request_EN_Data),
    .Request_Addr_Data(Request_Addr_Data),
    .Request_Data_Data(Request_Data_Data),

    .M1ZF(M1ZF),
    .M1CF(M1CF),
    .M1SF(M1SF),
    .M1OF(M1OF),
    .M1CSRWr(M1CSRWr),
    .M1DataREN(M1DataREN),
    .M1DataWEN(M1DataWEN),
    .M1Ebreak(M1Ebreak),
    .M1Ecall(M1Ecall),
    .M1InstrAccessFault(M1InstrAccessFault),
    .M1InstrFault(M1InstrFault),
    .M1InstrPageFault(M1InstrPageFault),
    .M1IsCSR(M1IsCSR),
    .M1IsInstr(M1IsInstr),
    .M1PredTaken(M1PredTaken),
    .M1RegWr(M1RegWr),
    .M1Ret(M1Ret),
    .M1RetType(M1RetType),
    .M1MemCtr(M1MemCtr),
    .M1RegSrc(M1RegSrc),
    .M1BranchCtr(M1BranchCtr),
    .M1Rd(M1Rd),
    .M1CSRRd(M1CSRRd),
    .M1BusA(M1BusA),
    .M1BusB(M1BusB),
    .M1BusW(M1BusW),
    .M1CSRin(M1CSRin),
    .M1CSRout(M1CSRout),
    .M1imm(M1imm),
    .M1Instr(M1Instr),
    .M1PC(M1PC),
    .M1PCCtrPC1(M1PCCtrPC1),
    .M1PCPlus4(M1PCPlus4),
    .M2ZF(M2ZF),
    .M2CF(M2CF),
    .M2SF(M2SF),
    .M2OF(M2OF),
    .M2CSRWr(M2CSRWr),
    .M2DataREN(M2DataREN),
    .M2DataWEN(M2DataWEN),
    .M2Ebreak(M2Ebreak),
    .M2Ecall(M2Ecall),
    .M2InstrAccessFault(M2InstrAccessFault),
    .M2InstrFault(M2InstrFault),
    .M2InstrPageFault(M2InstrPageFault),
    .M2IsCSR(M2IsCSR),
    .M2IsInstr(M2IsInstr),
    .M2LoadAlignFault(M2LoadAlignFault),
    .M2PredTaken(M2PredTaken),
    .M2RegWr(M2RegWr),
    .M2Ret(M2Ret),
    .M2RetType(M2RetType),
    .M2StoreAlignFault(M2StoreAlignFault),
    .M2MemCtr(M2MemCtr),
    .M2RegSrc(M2RegSrc),
    .M2BranchCtr(M2BranchCtr),
    .M2Rd(M2Rd),
    .M2CSRRd(M2CSRRd),
    .M2BusA(M2BusA),
    .M2BusB(M2BusB),
    .M2BusW(M2BusW),
    .M2CSRin(M2CSRin),
    .M2CSRout(M2CSRout),
    .M2imm(M2imm),
    .M2Instr(M2Instr),
    .M2PC(M2PC),
    .M2PCCtrPC1(M2PCCtrPC1),
    .M2PCPlus4(M2PCPlus4)
);

M2Stage M2Stage (
    .CLK(CLK),
    .RST(RST),
    .Flush(Trap | MemWait),
    .MIE(MIE),
    .MPIE(MPIE),
    .SIE(SIE),
    .SPIE(SPIE),
    .SPP(SPP),
    .MPP(MPP),
    .Privilege(Privilege),
    .medeleg(medeleg),
    .mepc(mepc),
    .mideleg(mideleg),
    .mie(mie),
    .mip(mip),
    .sepc(sepc),
    .ActualJump(ActualJump),
    .MemWait(MemWait),
    .NextMIE(NextMIE),
    .NextMPIE(NextMPIE),
    .NextSIE(NextSIE),
    .NextSPIE(NextSPIE),
    .NextSPP(NextSPP),
    .PredJump(PredJump),
    .PrivilegeChange(PrivilegeChange),
    .Ret(Ret),
    .RetType(RetType),
    .Trap(Trap),
    .TrapType(TrapType),
    .NextMPP(NextMPP),
    .NextPrivilege(NextPrivilege),
    .Nextmcause(Nextmcause),
    .Nextmepc(Nextmepc),
    .Nextmtval(Nextmtval),
    .Nextscause(Nextscause),
    .Nextsepc(Nextsepc),
    .Nextstval(Nextstval),

    .Respond_Fault_Data(Respond_Fault_Data),
    .Respond_Valid_Data(Respond_Valid_Data),
    .Respond_Data_Data(Respond_Data_Data),

    .IDPredTaken(IDPredTaken),
    .M2InstrAlignFault(M2InstrAlignFault),
    .IDBranchCtr(IDBranchCtr),
    .IDimm(IDimm),
    .IDPC(IDPC),
    .M2PCCtrPC2(M2PCCtrPC2),
    .M2PCCtr(M2PCCtr),
    .M2ObjAddr(M2ObjAddr),
    .M2Offset(M2Offset),

    .M2ZF(M2ZF),
    .M2CF(M2CF),
    .M2SF(M2SF),
    .M2OF(M2OF),
    .M2CSRWr(M2CSRWr),
    .M2DataREN(M2DataREN),
    .M2DataWEN(M2DataWEN),
    .M2Ebreak(M2Ebreak),
    .M2Ecall(M2Ecall),
    .M2InstrAccessFault(M2InstrAccessFault),
    .M2InstrFault(M2InstrFault),
    .M2InstrPageFault(M2InstrPageFault),
    .M2IsCSR(M2IsCSR),
    .M2IsInstr(M2IsInstr),
    .M2LoadAlignFault(M2LoadAlignFault),
    .M2PredTaken(M2PredTaken),
    .M2RegWr(M2RegWr),
    .M2Ret(M2Ret),
    .M2RetType(M2RetType),
    .M2StoreAlignFault(M2StoreAlignFault),
    .M2MemCtr(M2MemCtr),
    .M2RegSrc(M2RegSrc),
    .M2BranchCtr(M2BranchCtr),
    .M2Rd(M2Rd),
    .M2CSRRd(M2CSRRd),
    .M2BusA(M2BusA),
    .M2BusB(M2BusB),
    .M2BusW(M2BusW),
    .M2CSRin(M2CSRin),
    .M2CSRout(M2CSRout),
    .M2imm(M2imm),
    .M2Instr(M2Instr),
    .M2PC(M2PC),
    .M2PCCtrPC1(M2PCCtrPC1),
    .M2PCPlus4(M2PCPlus4),
    .WBCSRWr(WBCSRWr),
    .WBIsCSR(WBIsCSR),
    .WBIsInstr(WBIsInstr),
    .WBRegWr(WBRegWr),
    .WBRegSrc(WBRegSrc),
    .WBRd(WBRd),
    .WBCSRRd(WBCSRRd),
    .WBBusW(WBBusW),
    .WBCSRin(WBCSRin),
    .WBCSRout(WBCSRout),
    .WBimm(WBimm),
    .WBmem(WBmem),
    .WBPCPlus4(WBPCPlus4)
);

WBStage WBStage (
    .Regin(Regin),

    .WBRegSrc(WBRegSrc),
    .WBBusW(WBBusW),
    .WBCSRout(WBCSRout),
    .WBimm(WBimm),
    .WBmem(WBmem),
    .WBPCPlus4(WBPCPlus4)
);

RegByPass RegByPass (
    .IDBusAused(IDBusAused),
    .IDBusBused(IDBusBused),
    .EXRegWr(EXRegWr),
    .M1RegWr(M1RegWr),
    .M2RegWr(M2RegWr),
    .WBRegWr(WBRegWr),
    .EXRegSrc(EXRegSrc),
    .M1RegSrc(M1RegSrc),
    .M2RegSrc(M2RegSrc),
    .IDRs1(IDRs1),
    .IDRs2(IDRs2),
    .EXRd(EXRd),
    .M1Rd(M1Rd),
    .M2Rd(M2Rd),
    .WBRd(WBRd),
    .RegoutA(RegoutA),
    .RegoutB(RegoutB),
    .EXBusW(EXBusW),
    .EXCSRout(EXCSRout),
    .EXimm(EXimm),
    .EXPCPlus4(EXPCPlus4),
    .M1BusW(M1BusW),
    .M1CSRout(M1CSRout),
    .M1imm(M1imm),
    .M1PCPlus4(M1PCPlus4),
    .M2BusW(M2BusW),
    .M2CSRout(M2CSRout),
    .M2imm(M2imm),
    .M2PCPlus4(M2PCPlus4),
    .Regin(Regin),
    .RegWait(RegWait),
    .IDBusA(IDBusA),
    .IDBusB(IDBusB)
);

CSRHazard CSRHazzard (
    .IDIsCSR(IDIsCSR),
    .EXIsCSR(EXIsCSR),
    .EXCSRWr(EXCSRWr),
    .M1IsCSR(M1IsCSR),
    .M1CSRWr(M1CSRWr),
    .M2IsCSR(M2IsCSR),
    .M2CSRWr(M2CSRWr),
    .WBIsCSR(WBIsCSR),
    .WBCSRWr(WBCSRWr),
    .IDCSRRd(IDCSRRd),
    .EXCSRRd(EXCSRRd),
    .M1CSRRd(M1CSRRd),
    .M2CSRRd(M2CSRRd),
    .WBCSRRd(WBCSRRd),
    .CSRWait(CSRWait)
);

endmodule
