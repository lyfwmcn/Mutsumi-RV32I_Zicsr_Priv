`timescale 1ns / 1ns

// 外部模块需保证 mepc[1:0] = 2'h0
module PCReg (
    input CLK,
    input RST,
    input PCCtr,
    input Stall,
    input Ret,
    input RetType,
    input Trap,
    input TrapType,
    input [31:0] mepc,
    input [31:0] mtvec,
    input [31:0] ObjAddr,
    input [31:0] Offset,
    input [31:0] sepc,
    input [31:0] stvec,
    output InstrAlignFault,
    output [31:0] PC,
    output [31:0] PCCtrPC
);

reg [31:0] PCAddr;

// 需保证 PC[1:0] = 2'h0
assign PC = PCAddr;
assign PCCtrPC = PCCtr == 1'h1 ? ObjAddr + Offset :
                 Stall == 1'h1 ? PCAddr :
                 PCAddr + 32'h4;
assign InstrAlignFault = PCCtrPC[1:0] != 2'h0;

always @(posedge CLK or posedge RST) begin
    if (RST == 1'h1) begin
        PCAddr <= 32'h0;
    end
    else begin
        PCAddr <= Trap == 1'h1 ? (TrapType ? {stvec[31:2], 2'h0} : {mtvec[31:2], 2'h0}) : // 目前只支持直接跳转模式
                  Ret == 1'h1 ? (RetType ? {sepc[31:2], 2'h0} : {mepc[31:2], 2'h0}) :
                  InstrAlignFault == 1'h0 ? PCCtrPC :
                  PCAddr + 32'h4;                      // 兜底分支，实际由于 TrapFlush 不会发生
    end
end

endmodule
