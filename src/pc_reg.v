`timescale 1ns / 1ns

module pc_reg (
    input             clk,
    input             actual_jump,
    input             stall,
    input             ret,
    input             ret_type,
    input             trap,
    input             trap_type,
    input             predtaken,
    input      [31:0] id_jump_addr,
    input      [31:0] m2_jump_addr,
    input      [31:0] mepc,
    input      [31:0] mtvec,
    input      [31:0] sepc,
    input      [31:0] stvec,
    output reg [31:0] pc,
    output     [31:0] pcplus4
);

initial begin
    pc = 32'h0;
end

assign pcplus4 = pc + 32'h4;

always @(posedge clk) begin
    pc <= trap ? (trap_type ? {stvec[31:2], 2'h0} : {mtvec[31:2], 2'h0}) : // 目前只支持直接跳转模式
          ret ? (ret_type ? {sepc[31:2], 2'h0} : {mepc[31:2], 2'h0}) :
          actual_jump ? {m2_jump_addr[31:2], 2'h0} :
          predtaken? {id_jump_addr[31:2], 2'h0} :
          stall ? pc : pcplus4;
end

endmodule
