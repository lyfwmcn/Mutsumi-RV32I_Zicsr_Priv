`timescale 1ns / 1ns

module wb_stage (
    // 全局参数
    output [31:0] wb_reg_in,

    // 流水线参数
    input  [2:0]  wb_reg_src,
    input  [31:0] wb_alu_out,
    input  [31:0] wb_csr_out,
    input  [31:0] wb_imm,
    input  [31:0] wb_mem,
    input  [31:0] wb_pcplus4,
    input  [31:0] wb_pcplusimm
);

assign wb_reg_in = wb_reg_src == 3'h0 ? wb_alu_out :
                wb_reg_src == 3'h1 ? wb_pcplus4 :
                wb_reg_src == 3'h2 ? wb_pcplusimm :
                wb_reg_src == 3'h3 ? wb_mem :
                wb_reg_src == 3'h4 ? wb_imm :
                wb_reg_src == 3'h5 ? wb_csr_out :
                32'h0;

endmodule
