`timescale 1ns / 1ns

// 5.057 ns
module csr_hazard (
    input        ex1_is_csr,
    input        ex2_csr_wr,
    input        ex2_is_csr,
    input        m1_csr_wr,
    input        m1_is_csr,
    input        m2_csr_wr,
    input        m2_is_csr,
    input        wb_csr_wr,
    input        wb_is_csr,
    input [11:0] ex1_csr_rd,
    input [11:0] ex2_csr_rd,
    input [11:0] m1_csr_rd,
    input [11:0] m2_csr_rd,
    input [11:0] wb_csr_rd,
    output       csr_wait
);

wire [11:0] id_pair_csr_rd;
assign id_pair_csr_rd = ex1_csr_rd == 12'h100 ? 12'h300 :
                        ex1_csr_rd == 12'h104 ? 12'h304 :
                        ex1_csr_rd == 12'h144 ? 12'h344 :
                        ex1_csr_rd == 12'h300 ? 12'h100 :
                        ex1_csr_rd == 12'h304 ? 12'h104 :
                        ex1_csr_rd == 12'h344 ? 12'h144 :
                        12'h0;

assign csr_wait = ex1_is_csr &&
                  ((ex2_is_csr && ex2_csr_wr && (ex2_csr_rd == ex1_csr_rd || (id_pair_csr_rd == 12'h0 ? 1'h0 : ex2_csr_rd == id_pair_csr_rd))) ||
                  (m1_is_csr && m1_csr_wr && (m1_csr_rd == ex1_csr_rd || (id_pair_csr_rd == 12'h0 ? 1'h0 : m1_csr_rd == id_pair_csr_rd))) ||
                  (m2_is_csr && m2_csr_wr && (m2_csr_rd == ex1_csr_rd || (id_pair_csr_rd == 12'h0 ? 1'h0 : m2_csr_rd == id_pair_csr_rd))) ||
                  (wb_is_csr && wb_csr_wr && (wb_csr_rd == ex1_csr_rd || (id_pair_csr_rd == 12'h0 ? 1'h0 : wb_csr_rd == id_pair_csr_rd))));

endmodule
