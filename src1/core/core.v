`timescale 1ns / 1ns

module core (
    input clk,
    input rst_n
);

reg_file u_reg_file (
    .clk      (clk),
    .reg_wr   (),
    .rd       (),
    .rs1      (),
    .rs2      (),
    .reg_in   (),
    .reg_out_a(),
    .reg_out_b()
);



endmodule
