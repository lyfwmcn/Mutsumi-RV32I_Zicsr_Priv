`timescale 1ns / 1ns

/**
 * 接口说明：
 * i_core_request_vaddr:   vaddr[31:2]
 * i_core_respond_a_fault: access fault
 * i_core_respond_p_fault: page fault
 * i_core_respond_data:    读出数据
 */
module i_mmu (
    input              clk,
    input              rst_n,

    // 第一周期
    input              MPRV,
    input              MXR,
    input              SUM,
    input      [1:0]   MPP,
    input      [1:0]   privilege,
    input      [31:0]  pmpaddr0,
    input      [31:0]  pmpaddr1,
    input      [31:0]  pmpaddr2,
    input      [31:0]  pmpaddr3,
    input      [31:0]  pmpcfg0,
    input      [31:0]  satp,

    // 第一周期
    input      [29:0]  i_core_request_vaddr,
    output reg         i_core_request_busy,

    // 第三周期
    input              i_core_request_valid,
    output reg         i_core_respond_valid,
    output reg         i_core_respond_flush,
    output reg         i_core_respond_a_fault,
    output reg         i_core_respond_p_fault,
    output reg [31:0]  i_core_respond_data,

    // d-mmu 通信
    input              d_mmu_request_flush,
    input              d_mmu_request_f_by_va,
    input      [29:0]  d_mmu_request_vaddr,
    output             d_mmu_respond_ready,

    // 第一周期
    input              i_cache_request_busy,
    output     [9:0]   i_cache_request_paddr_lo,

    // 第二周期
    output     [21:0]  i_cache_request_paddr_hi,

    // 第三周期
    input              i_cache_respond_valid,
    input              i_cache_respond_flush,
    input      [31:0]  i_cache_respond_data,
    output             i_cache_request_valid,

    // d_cache 通信
    input              d_cache_respond_valid,
    input      [31:0]  d_cache_respond_data,
    output             d_cache_request_valid,
    output     [31:0]  d_cache_request_paddr
);

endmodule
