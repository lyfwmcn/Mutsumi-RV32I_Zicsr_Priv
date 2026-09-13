`timescale 1ns / 1ns

// 需保证 BranchCtr[4:3] = 2'h0, 2'h2-2'h3 时 BranchCtr[2:0] = 3'h0，BranchCtr[4:3] = 2'h1 时 BranchCtr[2:0] = 3'h0-3'h1, 3'h4-3'h7
// 需保证 BranchCtr[4:3] = 2'h0, 2'h3 时 PredTaken = 1'h0
module BU (
    input M2ZF,
    input M2CF,
    input M2SF,
    input M2OF,
    input IDPredTaken,
    input M2PredTaken,
    input [4:0] IDBranchCtr,
    input [4:0] M2BranchCtr,
    input [31:0] IDimm,
    input [31:0] IDPC,
    input [31:0] M2BusA,
    input [31:0] M2imm,
    input [31:0] M2PC,
    input [31:0] M2PCCtrPC1,
    input [31:0] M2PCCtrPC2,
    input [31:0] M2PCPlus4,
    output ActualJump,
    output M2PCCtr,
    output PredJump,
    output [31:0] M2nextPC,
    output [31:0] M2ObjAddr,
    output [31:0] M2Offset
);

wire Condsatisfieds [7:0];
assign Condsatisfieds[0] = M2ZF;
assign Condsatisfieds[1] = !M2ZF;
assign Condsatisfieds[4] = M2SF ^ M2OF;
assign Condsatisfieds[5] = !(M2SF ^ M2OF);
assign Condsatisfieds[6] = M2CF;
assign Condsatisfieds[7] = !M2CF;

assign Condsatisfieds[2] = 1'h0;
assign Condsatisfieds[3] = 1'h0;

wire Condsatisfied;
assign Condsatisfied = Condsatisfieds[M2BranchCtr[2:0]];

wire [2:0] Cond;
wire [2:0] Conds [3:0];
assign Conds[0] = IDPredTaken ? 3'h1 : 3'h0;
assign Conds[1] = Condsatisfied ? (M2PredTaken ? (IDPredTaken ? 3'h1 : 3'h0) : 3'h2) :
                  (M2PredTaken ? 3'h4 : (IDPredTaken ? 3'h1 : 3'h0));
assign Conds[2] = M2PredTaken ? (IDPredTaken ? 3'h1 : 3'h0) : 3'h2;
assign Conds[3] = 3'h3;
assign Cond = Conds[M2BranchCtr[4:3]];

assign ActualJump = Cond >= 3'h2 && Cond <= 3'h4;
assign PredJump = Cond == 3'h1;
assign M2PCCtr = Cond != 3'h0;
assign M2ObjAddr = Cond == 3'h0 ? 32'h0 :
                   Cond == 3'h1 ? IDPC :
                   Cond == 3'h3 ? M2BusA :
                   Cond <= 3'h4 ? M2PC :
                   32'h0;
assign M2Offset = Cond == 3'h0 ? 32'h0 :
                  Cond == 3'h1 ? IDimm :
                  Cond == 3'h4 ? 32'h4 :
                  Cond <= 3'h3 ? M2imm :
                  32'h0;
assign M2nextPC = M2BranchCtr[4:3] == 2'h0 ? M2PCPlus4 :
                  M2BranchCtr[4:3] == 2'h1 ? (Condsatisfied ? (M2PredTaken ? M2PCCtrPC1 : M2PCCtrPC2) : M2PCPlus4) :
                  M2BranchCtr[4:3] == 2'h2 ? (M2PredTaken ? M2PCCtrPC1 : M2PCCtrPC2) :
                  M2BranchCtr[4:3] == 2'h2 ? M2PCCtrPC2 :
                  32'h0;

endmodule
