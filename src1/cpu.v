`timescale 1ns / 1ns

module cpu (
    input              clk,
    input              rst_n,

    // ram 通信
    input              d_ram_request_busy,
    input              d_ram_respond_valid,
    input      [15:0]  d_ram_respond_data,
    output             d_ram_request_valid,
    output             d_ram_request_op,
    output     [15:0]  d_ram_request_sel,
    output     [31:0]  d_ram_request_addr,
    output     [127:0] d_ram_request_data,

    input              i_ram_request_busy,
    input              i_ram_respond_valid,
    input      [15:0]  i_ram_respond_data,
    output             i_ram_request_valid,
    output     [31:0]  i_ram_request_addr
);

d_cache u_d_cache (
    .clk                    (clk),

    .d_mmu_request_op       (),
    .d_mmu_request_sel      (),
    .d_mmu_request_paddr_lo (),
    .d_mmu_request_data     (),
    .d_mmu_request_busy     (),

    .d_mmu_request_paddr_hi (),

    .d_mmu_request_valid    (),
    .d_mmu_request_cacheable(),
    .d_mmu_respond_valid    (),
    .d_mmu_respond_flush    (),
    .d_mmu_respond_data     (),

    .i_cache_respond_done   (),
    .i_cache_request_flush  (),

    .d_ram_request_busy     (d_ram_request_busy),
    .d_ram_respond_valid    (d_ram_respond_valid),
    .d_ram_respond_data     (d_ram_respond_data),
    .d_ram_request_valid    (d_ram_request_valid),
    .d_ram_request_op       (d_ram_request_op),
    .d_ram_request_sel      (d_ram_request_sel),
    .d_ram_request_addr     (d_ram_request_addr),
    .d_ram_request_data     (d_ram_request_data)
);

i_cache u_i_cache (
    .clk                   (clk),

    .i_mmu_request_paddr_lo(),
    .i_mmu_request_busy    (),

    .i_mmu_request_paddr_hi(),

    .i_mmu_request_valid   (),
    .i_mmu_respond_valid   (),
    .i_mmu_respond_flush   (),
    .i_mmu_respond_data    (),

    .d_cache_request_flush (),
    .d_cache_respond_done  (),

    .i_ram_request_busy    (i_ram_request_busy),
    .i_ram_respond_valid   (i_ram_respond_valid),
    .i_ram_respond_data    (i_ram_respond_data),
    .i_ram_request_valid   (i_ram_request_valid),
    .i_ram_request_addr    (i_ram_request_addr)
);

endmodule
