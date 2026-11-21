`timescale 1ns / 1ns

module core (
    input              clk,
    input              rst_n,

    // 中断
    input             external_clear,
    input             external_set,
    input             timer_clear,
    input             timer_set,

    // 第一周期
    output             MPRV,
    output             MXR,
    output             SUM,
    output     [1:0]   MPP,
    output     [1:0]   privilege,
    output     [31:0]  pmpaddr0,
    output     [31:0]  pmpaddr1,
    output     [31:0]  pmpaddr2,
    output     [31:0]  pmpaddr3,
    output     [31:0]  pmpcfg0,
    output     [31:0]  satp,

    input      [1:0]   d_mmu_request_op,
    input              d_mmu_request_f_by_va,
    input      [3:0]   d_mmu_request_sel,
    input      [29:0]  d_mmu_request_vaddr,
    input      [31:0]  d_mmu_request_data,
    output reg         d_mmu_request_busy,

    input      [29:0]  i_mmu_request_vaddr,
    output reg         i_mmu_request_busy,

    // 第三周期
    input              d_mmu_request_valid,
    output reg         d_mmu_respond_valid,
    output reg         d_mmu_respond_flush,
    output reg         d_mmu_respond_a_fault,
    output reg         d_mmu_respond_p_fault,
    output reg [31:0]  d_mmu_respond_data,

    input              i_mmu_request_valid,
    output reg         i_mmu_respond_valid,
    output reg         i_mmu_respond_flush,
    output reg         i_mmu_respond_a_fault,
    output reg         i_mmu_respond_p_fault,
    output reg [31:0]  i_mmu_respond_data
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
