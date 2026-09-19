`timescale 1ns / 1ns

// 输入 1.9 ns，输出 2.8 ns
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

reg [31:0] regs [1:31];

assign reg_out_a = rs1 == 5'h0 ? 32'h0 : regs[rs1];
assign reg_out_b = rs2 == 5'h0 ? 32'h0 : regs[rs2];

integer i;

initial begin
    for (i = 1; i < 32; i = i + 1) begin
        regs[i] = 32'h0;
    end
end

always @(posedge clk) begin
    if (reg_wr == 1'h1 && rd > 5'h0) begin
        regs[rd] <= reg_in;
    end
end

endmodule
