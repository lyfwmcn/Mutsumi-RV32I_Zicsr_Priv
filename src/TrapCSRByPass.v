`timescale 1ns / 1ns

// 需保证 WBCSRin 符合格式
module TrapCSRByPass (
    input CurMIE,
    input CurMPIE,
    input CurSIE,
    input CurSPIE,
    input CurSPP,
    input WBCSRWr,
    input [1:0] CurMPP,
    input [11:0] WBCSRRd,
    input [31:0] Curmedeleg,
    input [31:0] Curmepc,
    input [31:0] Curmideleg,
    input [31:0] Curmie,
    input [31:0] Curmip,
    input [31:0] Curmtvec,
    input [31:0] Cursepc,
    input [31:0] Curstvec,
    input [31:0] WBCSRin,
    output MIE,
    output MPIE,
    output SIE,
    output SPIE,
    output SPP,
    output [1:0] MPP,
    output [31:0] medeleg,
    output [31:0] mepc,
    output [31:0] mideleg,
    output [31:0] mie,
    output [31:0] mip,
    output [31:0] mtvec,
    output [31:0] sepc,
    output [31:0] stvec
);

assign MIE = WBCSRWr == 1'h1 && WBCSRRd == 12'h300 ? WBCSRin[3] : CurMIE;
assign MPIE = WBCSRWr == 1'h1 && WBCSRRd == 12'h300 ? WBCSRin[7] : CurMPIE;
assign SIE = WBCSRWr == 1'h1 && (WBCSRRd == 12'h300 || WBCSRRd == 12'h100) ? WBCSRin[1] : CurSIE;
assign SPIE = WBCSRWr == 1'h1 && (WBCSRRd == 12'h300 || WBCSRRd == 12'h100) ? WBCSRin[5] : CurSPIE;
assign SPP = WBCSRWr == 1'h1 && (WBCSRRd == 12'h300 || WBCSRRd == 12'h100) ? WBCSRin[8] : CurSPP;
assign MPP = WBCSRWr == 1'h1 && WBCSRRd == 12'h300 ? WBCSRin[12:11] : CurMPP;
assign mtvec = WBCSRWr == 1'h1 && WBCSRRd == 12'h305 ? WBCSRin : Curmtvec;
assign mepc = WBCSRWr == 1'h1 && WBCSRRd == 12'h341 ? WBCSRin : Curmepc;
assign mip = WBCSRWr == 1'h0 ? Curmip :
             WBCSRRd == 12'h344 ? {Curmip[31:4], WBCSRin[3], Curmip[2], WBCSRin[1], Curmip[0]} :
             WBCSRRd == 12'h144 ? {Curmip[31:2], WBCSRin[1], Curmip[0]} :
             Curmip;
assign medeleg = WBCSRWr == 1'h1 && WBCSRRd == 12'h302 ? WBCSRin : Curmedeleg;
assign mideleg = WBCSRWr == 1'h1 && WBCSRRd == 12'h303 ? WBCSRin : Curmideleg;
assign mie = WBCSRWr == 1'h0 ? Curmie :
             WBCSRRd == 12'h304 ? WBCSRin :
             WBCSRRd == 12'h104 ? {Curmie[31:10], WBCSRin[9], Curmie[8:6], WBCSRin[5], Curmie[4:2], WBCSRin[1], Curmie[0]} :
             Curmie;
assign sepc = WBCSRWr == 1'h1 && WBCSRRd == 12'h141 ? WBCSRin : Cursepc;
assign stvec = WBCSRWr == 1'h1 && WBCSRRd == 12'h105 ? WBCSRin : Curstvec;

endmodule
