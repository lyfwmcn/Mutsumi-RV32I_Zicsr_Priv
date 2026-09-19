`timescale 1ns / 1ns

// 7.1 ns
module reg_bypass (
    input         ex1_alu_src_a,
    input         ex1_reg_out_a_used,
    input         ex1_reg_out_b_used,
    input         ex2_reg_wr,
    input         m1_reg_wr,
    input         m2_reg_wr,
    input         wb_reg_wr,
    input  [1:0]  ex1_alu_src_b,
    input  [2:0]  ex2_reg_src,
    input  [2:0]  m1_reg_src,
    input  [2:0]  m2_reg_src,
    input  [4:0]  ex1_rs1,
    input  [4:0]  ex1_rs2,
    input  [4:0]  ex2_rd,
    input  [4:0]  m1_rd,
    input  [4:0]  m2_rd,
    input  [4:0]  wb_rd,
    input  [31:0] ex1_reg_out_a,
    input  [31:0] ex1_reg_out_b,
    input  [31:0] m1_raw_reg_in,
    input  [31:0] m2_raw_reg_in,
    input  [31:0] wb_reg_in,
    output        reg_wait,
    output        ex1_rs1usem1,
    output        ex1_rs2usem1,
    output        ex1_aluinausem1,
    output        ex1_aluinbusem1,
    output [31:0] ex1_reg_out_a_true,
    output [31:0] ex1_reg_out_b_true
);

wire [3:0] cond_a;
assign cond_a = ex1_reg_out_a_used == 1'h0 || ex1_rs1 == 5'h0 ? 4'h8 :
               ex2_rd == ex1_rs1 && ex2_reg_wr == 1'h1 ? (ex2_reg_src[2] == 1'h1 ? 4'h7 : 4'h6) :
               m1_rd == ex1_rs1 && m1_reg_wr == 1'h1 ? (m1_reg_src[2] == 1'h1 ? 4'h5 : 4'h4) :
               m2_rd == ex1_rs1 && m2_reg_wr == 1'h1 ? (m2_reg_src[2] == 1'h1 ? 4'h3 : 4'h2) :
               wb_rd == ex1_rs1 && wb_reg_wr == 1'h1 ? 4'h1 : 4'h0;

wire [3:0] cond_b;
assign cond_b = ex1_reg_out_b_used == 1'h0 || ex1_rs2 == 5'h0 ? 4'h8 :
               ex2_rd == ex1_rs2 && ex2_reg_wr == 1'h1 ? (ex2_reg_src[2] == 1'h1 ? 4'h7 : 4'h6) :
               m1_rd == ex1_rs2 && m1_reg_wr == 1'h1 ? (m1_reg_src[2] == 1'h1 ? 4'h5 : 4'h4) :
               m2_rd == ex1_rs2 && m2_reg_wr == 1'h1 ? (m2_reg_src[2] == 1'h1 ? 4'h3 : 4'h2) :
               wb_rd == ex1_rs2 && wb_reg_wr == 1'h1 ? 4'h1 : 4'h0;

wire [31:0] ex1_reg_out_a_trues [8:0];

assign ex1_reg_out_a_trues[0] = ex1_reg_out_a;
assign ex1_reg_out_a_trues[1] = wb_reg_in;
assign ex1_reg_out_a_trues[2] = m2_raw_reg_in;
assign ex1_reg_out_a_trues[3] = 32'h0;
assign ex1_reg_out_a_trues[4] = m1_raw_reg_in;
assign ex1_reg_out_a_trues[5] = 32'h0;
assign ex1_reg_out_a_trues[6] = 32'h0;
assign ex1_reg_out_a_trues[7] = 32'h0;
assign ex1_reg_out_a_trues[8] = 32'h0;

assign ex1_reg_out_a_true = ex1_reg_out_a_trues[cond_a];

wire [31:0] ex1_reg_out_b_trues [8:0];

assign ex1_reg_out_b_trues[0] = ex1_reg_out_b;
assign ex1_reg_out_b_trues[1] = wb_reg_in;
assign ex1_reg_out_b_trues[2] = m2_raw_reg_in;
assign ex1_reg_out_b_trues[3] = 32'h0;
assign ex1_reg_out_b_trues[4] = m1_raw_reg_in;
assign ex1_reg_out_b_trues[5] = 32'h0;
assign ex1_reg_out_b_trues[6] = 32'h0;
assign ex1_reg_out_b_trues[7] = 32'h0;
assign ex1_reg_out_b_trues[8] = 32'h0;

assign ex1_reg_out_b_true = ex1_reg_out_b_trues[cond_b];

assign reg_wait = cond_a == 4'h3 || cond_a == 4'h5 || cond_a == 4'h7 ||
              cond_b == 4'h3 || cond_b == 4'h5 || cond_b == 4'h7;
assign ex1_rs1usem1 = cond_a == 4'h6;
assign ex1_rs2usem1 = cond_b == 4'h6;

assign ex1_aluinausem1 = ex1_rs1usem1 && ex1_alu_src_a == 1'h0;
assign ex1_aluinbusem1 = ex1_rs2usem1 && ex1_alu_src_b == 2'h0;

endmodule
