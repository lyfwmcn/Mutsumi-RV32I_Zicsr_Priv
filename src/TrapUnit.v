`timescale 1ns / 1ns

// 需保证 Privilege = 2'h0, 2'h1, 2'h3
// 需保证 MPP = 2'h0, 2'h1, 2'h3
module TrapUnit (
    input M2Ebreak,
    input M2Ecall,
    input M2InstrAccessFault,
    input M2InstrAlignFault,
    input M2InstrFault,
    input M2InstrPageFault,
    input M2LoadAccessFault,
    input M2LoadAlignFault,
    input M2LoadPageFault,
    input M2StoreAccessFault,
    input M2StoreAlignFault,
    input M2StorePageFault,
    input MIE,
    input MPIE,
    input Ret,
    input RetType,
    input SIE,
    input SPIE,
    input SPP,
    input [1:0] MPP,
    input [1:0] Privilege,
    input [31:0] M2BusW,
    input [31:0] M2Instr,
    input [31:0] M2PC,
    input [31:0] M2PCCtrPC2,
    input [31:0] medeleg,
    input [31:0] mideleg,
    input [31:0] mie,
    input [31:0] mip,
    input [31:0] WBnextPC,
    output NextMIE,
    output NextMPIE,
    output NextSIE,
    output NextSPIE,
    output PrivilegeChange,
    output Trap,
    output TrapType,
    output [1:0] NextMPP,
    output [1:0] NextPrivilege,
    output [31:0] Nextmcause,
    output [31:0] Nextmepc,
    output [31:0] Nextmtval,
    output [31:0] Nextscause,
    output [31:0] Nextsepc,
    output [31:0] Nextstval
);

wire [3:0] _exceptioncause;
assign _exceptioncause = M2InstrPageFault ? 4'hc :
                         M2InstrAccessFault ? 4'h1 :
                         M2InstrFault ? 4'h2 :
                         M2Ebreak ? 4'h3 :
                         M2Ecall ? (Privilege == 2'h0 ? 4'h8 : Privilege == 2'h1 ? 4'h9 : 4'hb) :
                         M2InstrAlignFault ? 4'h0 :
                         M2LoadAlignFault ? 4'h4 :
                         M2LoadPageFault ? 4'hd :
                         M2LoadAccessFault ? 4'h5 :
                         M2StoreAlignFault ? 4'h6 :
                         M2StorePageFault ? 4'hf :
                         M2StoreAccessFault ? 4'h7 :
                         4'ha;

wire [3:0] _interruptcause;
assign _interruptcause = mip[11] && mie[11] && (mideleg[11] && Privilege <= 2'h1 ? SIE : MIE) ? 4'hb :
                         mip[3]  && mie[3]  && (mideleg[3]  && Privilege <= 2'h1 ? SIE : MIE) ? 4'h3 :
                         mip[7]  && mie[7]  && (mideleg[7]  && Privilege <= 2'h1 ? SIE : MIE) ? 4'h7 :
                         mip[9]  && mie[9]  && (mideleg[9]  && Privilege <= 2'h1 ? SIE : MIE) ? 4'h9 :
                         mip[1]  && mie[1]  && (mideleg[1]  && Privilege <= 2'h1 ? SIE : MIE) ? 4'h1 :
                         mip[5]  && mie[5]  && (mideleg[5]  && Privilege <= 2'h1 ? SIE : MIE) ? 4'h5 :
                         4'h0;

assign Trap = _exceptioncause != 4'ha || _interruptcause != 4'h0;
assign TrapType = Trap && NextPrivilege == 2'h1;
assign PrivilegeChange = Trap || Ret;
// 需保证 NextPrivilege = 2'h0, 2'h1, 2'h3
assign NextPrivilege = Trap ? (_exceptioncause == 4'ha ? (mideleg[{1'h0, _interruptcause}] && Privilege <= 2'h1 ? 2'h1 : 2'h3) : (medeleg[{1'h0, _exceptioncause}] && Privilege <= 2'h1 ? 2'h1 : 2'h3)) :
                       Ret ? (RetType ? {1'h0, SPP} : MPP) :
                       2'h0;

assign NextMIE = Trap ? 1'h0 :
                 Ret ? (RetType ? 1'h0 : MPIE) :
                 1'h0;
assign NextMPIE = Trap ? (TrapType ? 1'h0 : MIE) :
                  Ret ? (RetType ? 1'h0 : 1'h1) :
                  1'h0;
assign NextSIE = Trap ? 1'h0 :
                 Ret ? (RetType ? SPIE : 1'h0) :
                 1'h0;
assign NextSPIE = Trap ? (TrapType ? SIE : 1'h0) :
                  Ret ? (RetType ? 1'h1 : 1'h0) :
                  1'h0;
// 需保证 NextMPP = 2'h0, 2'h1, 2'h3
assign NextMPP = Trap ? (TrapType ? 2'h0 : Privilege) :
                 Ret ? 2'h0 :
                 2'h0;
// 需保证 Nextmcause 符合格式
assign Nextmcause = Trap ? (TrapType ? 32'h0 : (_exceptioncause == 4'ha ? {1'h1, 27'h0, _interruptcause} : {28'h0, _exceptioncause})) :
                    32'h0;
// 需保证 Nextmepc 符合格式
assign Nextmepc = Trap ? (TrapType ? 32'h0 : (_exceptioncause == 4'ha ? WBnextPC : M2PC)) :
                  32'h0;
// 需保证 Nextmtval 符合格式
assign Nextmtval = !Trap ? 32'h0 :
                   TrapType ? 32'h0 :
                   _exceptioncause == 4'ha ? 32'h0 :
                   _exceptioncause == 4'h3 || _exceptioncause == 4'h8 || _exceptioncause == 4'h9 || _exceptioncause == 4'hb ? 32'h0 :
                   _exceptioncause == 4'h0 ? M2PCCtrPC2 :
                   _exceptioncause == 4'h1 || _exceptioncause == 4'hc ? M2PC :
                   _exceptioncause == 4'h2 ? M2Instr :
                   M2BusW;
assign Nextscause = Trap ? (TrapType ? (TrapType ? {1'h1, 27'h0, _interruptcause} : {28'h0, _exceptioncause}) : 32'h0) :
                    32'h0;
assign Nextsepc = Trap ? (TrapType ? (_exceptioncause == 4'ha ? WBnextPC : M2PC) : 32'h0) :
                  32'h0;
assign Nextstval = !Trap ? 32'h0 :
                   !TrapType ? 32'h0 :
                   _exceptioncause == 4'ha ? 32'h0 :
                   _exceptioncause == 4'h3 || _exceptioncause == 4'h8 || _exceptioncause == 4'h9 || _exceptioncause == 4'hb ? 32'h0 :
                   _exceptioncause == 4'h0 ? M2PCCtrPC2 :
                   _exceptioncause == 4'h1 || _exceptioncause == 4'hc ? M2PC :
                   _exceptioncause == 4'h2 ? M2Instr :
                   M2BusW;

endmodule
