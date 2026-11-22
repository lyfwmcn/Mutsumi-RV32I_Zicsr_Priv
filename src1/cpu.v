`timescale 1ns / 1ns

module cpu (
    input              clk,
    input              rst_n,

    input              external_clear,
    input              external_set,
    input              timer_clear,
    input              timer_set,

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

core u_core (
    .clk                  (clk),
    .rst_n                (rst_n),

    .external_clear       (external_clear),
    .external_set         (external_set),
    .timer_clear          (timer_clear),
    .timer_set            (timer_set),

    .MPRV                 (),
    .MXR                  (),
    .SUM                  (),
    .MPP                  (),
    .privilege            (),
    .pmpaddr0             (),
    .pmpaddr1             (),
    .pmpaddr2             (),
    .pmpaddr3             (),
    .pmpcfg0              (),
    .satp                 (),

    .d_mmu_request_op     (),
    .d_mmu_request_f_by_va(),
    .d_mmu_request_sel    (),
    .d_mmu_request_vaddr  (),
    .d_mmu_request_data   (),
    .d_mmu_request_busy   (),

    .i_mmu_request_vaddr  (),
    .i_mmu_request_busy   (),

    .d_mmu_request_valid  (),
    .d_mmu_respond_valid  (),
    .d_mmu_respond_flush  (),
    .d_mmu_respond_a_fault(),
    .d_mmu_respond_p_fault(),
    .d_mmu_respond_data   (),

    .i_mmu_request_valid  (),
    .i_mmu_respond_valid  (),
    .i_mmu_respond_flush  (),
    .i_mmu_respond_a_fault(),
    .i_mmu_respond_p_fault(),
    .i_mmu_respond_data   ()
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
    .d_mmu_request_cache    (),
    .d_mmu_respond_valid    (),
    .d_mmu_respond_flush    (),
    .d_mmu_respond_data     (),

    .i_cache_respond_done   (),
    .i_cache_request_flush  (),

    .i_mmu_request_valid    (),
    .i_mmu_request_paddr    (),
    .i_mmu_respond_valid    (),
    .i_mmu_respond_data     (),

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

d_mmu u_d_mmu (
    .clk                     (clk),
    .rst_n                   (rst_n),

    .MPRV                    (),
    .MXR                     (),
    .SUM                     (),
    .MPP                     (),
    .privilege               (),
    .pmpaddr0                (),
    .pmpaddr1                (),
    .pmpaddr2                (),
    .pmpaddr3                (),
    .pmpcfg0                 (),
    .satp                    (),

    .d_core_request_op       (),
    .d_core_request_f_by_va  (),
    .d_core_request_sel      (),
    .d_core_request_vaddr    (),
    .d_core_request_data     (),
    .d_core_request_busy     (),

    .d_core_request_valid    (),
    .d_core_respond_valid    (),
    .d_core_respond_flush    (),
    .d_core_respond_a_fault  (),
    .d_core_respond_p_fault  (),
    .d_core_respond_data     (),

    .i_mmu_respond_ready     (),
    .i_mmu_request_flush     (),
    .i_mmu_request_f_by_va   (),
    .i_mmu_request_vaddr     (),

    .d_cache_request_busy    (),
    .d_cache_request_op      (),
    .d_cache_request_sel     (),
    .d_cache_request_paddr_lo(),
    .d_cache_request_data    (),

    .d_cache_request_paddr_hi(),

    .d_cache_respond_valid   (),
    .d_cache_respond_flush   (),
    .d_cache_respond_data    (),
    .d_cache_request_valid   (),
    .d_cache_request_cache   ()
);

i_mmu u_i_mmu (
    .clk                     (clk),
    .rst_n                   (rst_n),

    .MPRV                    (),
    .MXR                     (),
    .SUM                     (),
    .MPP                     (),
    .privilege               (),
    .pmpaddr0                (),
    .pmpaddr1                (),
    .pmpaddr2                (),
    .pmpaddr3                (),
    .pmpcfg0                 (),
    .satp                    (),

    .i_core_request_vaddr    (),
    .i_core_request_busy     (),

    .i_core_request_valid    (),
    .i_core_respond_valid    (),
    .i_core_respond_flush    (),
    .i_core_respond_a_fault  (),
    .i_core_respond_p_fault  (),
    .i_core_respond_data     (),

    .d_mmu_request_flush     (),
    .d_mmu_request_f_by_va   (),
    .d_mmu_request_vaddr     (),
    .d_mmu_respond_ready     (),

    .i_cache_request_busy    (),
    .i_cache_request_paddr_lo(),

    .i_cache_request_paddr_hi(),

    .i_cache_respond_valid   (),
    .i_cache_respond_flush   (),
    .i_cache_respond_data    (),
    .i_cache_request_valid   (),

    .d_cache_respond_valid   (),
    .d_cache_respond_data    (),
    .d_cache_request_valid   (),
    .d_cache_request_paddr   ()
);

endmodule
