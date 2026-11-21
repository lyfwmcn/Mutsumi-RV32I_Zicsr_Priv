`timescale 1ns / 1ns

/**
 * 接口说明：
 * i_mmu_request_paddr_lo:  paddr[11:2]
 * i_mmu_request_paddr_hi:  paddr[33:12]
 * i_mmu_respond_data:      读出数据
 */
module i_cache (
    input              clk,

    // 第一周期
    input      [9:0]   i_mmu_request_paddr_lo,
    output             i_mmu_request_busy,

    // 第二周期
    input      [21:0]  i_mmu_request_paddr_hi,

    // 第三周期
    input              i_mmu_request_valid,
    output             i_mmu_respond_valid,
    output             i_mmu_respond_flush,
    output     [31:0]  i_mmu_respond_data,

    // d-cache 通信
    input              d_cache_request_flush,
    output             d_cache_respond_done,

    // ram 通信
    input              i_ram_request_busy,
    input              i_ram_respond_valid,
    input      [15:0]  i_ram_respond_data,
    output reg         i_ram_request_valid,
    output reg [31:0]  i_ram_request_addr
);

endmodule
