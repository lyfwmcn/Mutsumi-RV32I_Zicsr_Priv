`timescale 1ns / 1ns

/**
 * 接口说明：
 * d_mmu_request_op:       0: R  1: W  2: ALL_WRITE_BACK
 * d_mmu_request_sel:      (W  valid) 字节使能
 * d_mmu_request_paddr_lo: (RW valid) paddr[11:2]
 * d_mmu_request_data:     (W  valid) 写入数据
 * d_mmu_request_paddr_hi: (RW valid) paddr[33:12]
 * d_mmu_request_cache:    (RW valid) 读写是否可缓存
 * d_mmu_respond_data:     (R  valid) 读出数据
 * i_mmu_request_paddr:    paddr[33:2]
 * i_mmu_respond_data:     读出数据
 */
module d_cache (
    input              clk,

    // 第一周期
    input      [1:0]   d_mmu_request_op,
    input      [3:0]   d_mmu_request_sel,
    input      [9:0]   d_mmu_request_paddr_lo,
    input      [31:0]  d_mmu_request_data,
    output             d_mmu_request_busy,

    // 第二周期
    input      [21:0]  d_mmu_request_paddr_hi,

    // 第三周期
    input              d_mmu_request_valid,
    input              d_mmu_request_cache,
    output             d_mmu_respond_valid,
    output             d_mmu_respond_flush,
    output     [31:0]  d_mmu_respond_data,

    // i-mmu 通信
    input              i_mmu_request_valid,
    input      [31:0]  i_mmu_request_paddr,
    output             i_mmu_respond_valid,
    output     [31:0]  i_mmu_respond_data,

    // i-cache 通信
    input              i_cache_respond_done,
    output             i_cache_request_flush,

    // ram 通信
    input              d_ram_request_busy,
    input              d_ram_respond_valid,
    input      [15:0]  d_ram_respond_data,
    output reg         d_ram_request_valid,
    output reg         d_ram_request_op,
    output reg [15:0]  d_ram_request_sel,
    output reg [31:0]  d_ram_request_addr,
    output reg [127:0] d_ram_request_data
);

d_cache_ram u_d_cache_ram (
    .clk           (clk),

    .d_cache_re    (),
    .d_cache_raddr (),
    .d_cache_tag0  (),
    .d_cache_tag1  (),
    .d_cache_tag2  (),
    .d_cache_tag3  (),
    .d_cache_rdata0(),
    .d_cache_rdata1(),
    .d_cache_rdata2(),
    .d_cache_rdata3(),

    .d_cache_tag_we(),
    .d_cache_waddr (),
    .d_cache_we    (),
    .d_cache_tag_in(),
    .d_cache_in    ()
);

endmodule
