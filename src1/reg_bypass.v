`timescale 1ns / 1ns

module reg_bypass (
    input         id_reg_out_a_used,
    input         id_reg_out_b_used,
    input         id_alu_src_a,
    input         id_alu_src_b,
    input  [4:0]  id_rs1,
    input  [4:0]  id_rs2,
    input  [31:0] id_imm,
    input  [31:0] id_reg_out_a,
    input  [31:0] id_reg_out_b,

    input         ex_reg_wr,
    input  [2:0]  ex_reg_src,
    input  [4:0]  ex_rd,

    input         me_reg_wr,
    input  [2:0]  me_reg_src,
    input  [4:0]  me_rd,
    input  [31:0] me_raw_reg_in,

    input         wb_reg_wr,
    input  [4:0]  wb_rd,
    input  [31:0] wb_reg_in,

    output        reg_wait,
    output        id_rs2_src,
    output        id_alu_in_a_src,
    output        id_alu_in_b_src,
    output [31:0] id_alu_in_a,
    output [31:0] id_alu_in_b,
    output [31:0] id_reg_out_b_true
);

wire [2:0] cond_a = !id_reg_out_a_used || id_rs1 == 5'h0 ? 3'h6 :
                    ex_rd == id_rs1 && ex_reg_wr ? (ex_reg_src == 3'h3 ? 3'h5 : 3'h4) :
                    me_rd == id_rs1 && me_reg_wr ? (me_reg_src == 3'h3 ? 3'h3 : 3'h2) :
                    wb_rd == id_rs1 && wb_reg_wr ? 3'h1 : 3'h0;

wire [2:0] cond_b = !id_reg_out_b_used || id_rs2 == 5'h0 ? 3'h6 :
                    ex_rd == id_rs2 && ex_reg_wr ? (ex_reg_src == 3'h3 ? 3'h5 : 3'h4) :
                    me_rd == id_rs2 && me_reg_wr ? (me_reg_src == 3'h3 ? 3'h3 : 3'h2) :
                    wb_rd == id_rs2 && wb_reg_wr ? 3'h1 : 3'h0;


wire [31:0] id_reg_out_a_trues [6:0];
assign id_reg_out_a_trues[0] = id_reg_out_a;
assign id_reg_out_a_trues[1] = wb_reg_in;
assign id_reg_out_a_trues[2] = me_raw_reg_in;
assign id_reg_out_a_trues[3] = id_reg_out_a;
assign id_reg_out_a_trues[4] = id_reg_out_a;
assign id_reg_out_a_trues[5] = id_reg_out_a;
assign id_reg_out_a_trues[6] = id_reg_out_a;

wire [31:0] id_reg_out_a_true = id_reg_out_a_trues[cond_a];


wire [31:0] id_reg_out_b_trues [6:0];
assign id_reg_out_b_trues[0] = id_reg_out_b;
assign id_reg_out_b_trues[1] = wb_reg_in;
assign id_reg_out_b_trues[2] = me_raw_reg_in;
assign id_reg_out_b_trues[3] = id_reg_out_b;
assign id_reg_out_b_trues[4] = id_reg_out_b;
assign id_reg_out_b_trues[5] = id_reg_out_b;
assign id_reg_out_b_trues[6] = id_reg_out_b;

assign id_reg_out_b_true = id_reg_out_b_trues[cond_b];


assign reg_wait = cond_a == 3'h3 || cond_a == 3'h5 ||
                  cond_b == 3'h3 || cond_b == 3'h5;

wire   id_rs1_src = cond_a == 3'h4;
assign id_rs2_src = cond_b == 3'h4;

assign id_alu_in_a = !id_alu_src_a ? id_reg_out_a_true : 32'h0;

assign id_alu_in_b = !id_alu_src_b ? id_reg_out_b_true : id_imm;

assign id_alu_in_a_src = id_rs1_src && id_alu_src_a == 1'h0;
assign id_alu_in_b_src = id_rs2_src && id_alu_src_b == 1'h0;

endmodule
