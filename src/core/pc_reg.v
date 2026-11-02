`timescale 1ns / 1ns

module pc_reg (
    input             clk,
    input             rst_n,
    input             actual_jump,
    // 冲刷后重新取指（优先级高于 actual_jump，同拍不会同时出现）
    input             redirect,
    input      [31:0] redirect_pc,
    input             stall,
    // 取指请求没被接受（cache 忙 / 请求缓冲满）：pc 保持不变，避免跳过地址
    input             hold,
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

assign pcplus4 = pc + 32'h4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 32'h0;
    end
    else begin
        pc <= trap ? (trap_type ? {stvec[31:2], 2'h0} : {mtvec[31:2], 2'h0}) : // 目前只支持直接跳转模式
            ret ? (ret_type ? {sepc[31:2], 2'h0} : {mepc[31:2], 2'h0}) :
            redirect ? {redirect_pc[31:2], 2'h0} :
            actual_jump ? {m2_jump_addr[31:2], 2'h0} :
            predtaken? {id_jump_addr[31:2], 2'h0} :
            (stall | hold) ? pc : pcplus4;
    end
end

endmodule
