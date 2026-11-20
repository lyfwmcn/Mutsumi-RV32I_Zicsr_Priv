`timescale 1ns / 1ns

module reg_file (
    input         clk,
    input         reg_wr,
    input  [4:0]  rd,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [31:0] reg_in,
    output [31:0] reg_out_a,
    output [31:0] reg_out_b
);

(* ram_style = "distributed" *)
reg [31:0] regs [31:0];

initial begin
    regs[0] = 32'h0;
end

assign reg_out_a = regs[rs1];
assign reg_out_b = regs[rs2];

always @(posedge clk) begin
    if (reg_wr && rd != 5'h0) begin
        regs[rd] <= reg_in;
    end
end

endmodule
