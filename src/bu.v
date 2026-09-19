`timescale 1ns / 1ns

module bu (
    input         zf,
    input         cf,
    input         sf,
    input         of,
    input         predtaken,
    input         ret,
    input         ret_type,
    input [4:0]   branch_ctr,
    input [31:0]  alu_out,
    input [31:0]  mepc,
    input [31:0]  pcplus4,
    input [31:0]  pcplusimm,
    input [31:0]  sepc,
    output        actual_jump,
    output [31:0] jump_addr,
    output [31:0] nextpc
);

wire conds [7:0];
assign conds[0] = zf;
assign conds[1] = !zf;
assign conds[4] = sf ^ of;
assign conds[5] = !(sf ^ of);
assign conds[6] = cf;
assign conds[7] = !cf;

assign conds[2] = 1'h0;
assign conds[3] = 1'h0;

wire cond;
assign cond = conds[branch_ctr[2:0]];

wire needjump;
assign needjump = branch_ctr[4:3] == 2'h1 ? cond :
                  branch_ctr[4:3] != 2'h0;

assign actual_jump = predtaken ^ needjump;

assign nextpc = ret ? (ret_type ? {sepc[31:2], 2'h0} : {mepc[31:2], 2'h0}) :
                branch_ctr[4:3] == 2'h0 ? pcplus4 :
                branch_ctr[4:3] == 2'h3 ? alu_out :
                branch_ctr[4:3] == 2'h2 ? pcplusimm :
                cond ? pcplusimm : pcplus4;

assign jump_addr = predtaken ? pcplus4 :
                   branch_ctr[4:3] == 2'h3 ? alu_out :
                   pcplusimm;

endmodule
