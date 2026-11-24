`timescale 1ns / 1ns

/**
 * 接口说明：
 * d_core_request_op:      0: R  1: W  2: fence.i  3: sfence.vma
 * d_core_request_f_by_va: (S   valid) vaddr 是否有效
 * d_core_request_sel:     (W   valid) 字节使能
 * d_core_request_vaddr:   (RWS valid) vaddr[31:2]
 * d_core_request_data:    (W   valid) 写入数据
 * d_core_respond_a_fault: (RW  valid) access fault
 * d_core_respond_p_fault: (RW  valid) page fault
 * d_core_respond_data:    (R   valid) 读出数据
 */
module d_mmu (
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
    input      [1:0]   d_core_request_op,
    input              d_core_request_f_by_va,
    input      [3:0]   d_core_request_sel,
    input      [29:0]  d_core_request_vaddr,
    input      [31:0]  d_core_request_data,
    output reg         d_core_request_busy,

    // 第三周期
    input              d_core_request_valid,
    output reg         d_core_respond_valid,
    output reg         d_core_respond_flush,
    output reg         d_core_respond_a_fault,
    output reg         d_core_respond_p_fault,
    output reg [31:0]  d_core_respond_data,

    // i-mmu 通信
    input              i_mmu_respond_ready,
    output reg         i_mmu_request_flush,
    output reg         i_mmu_request_f_by_va,
    output reg [19:0]  i_mmu_request_vaddr,

    // 第一周期
    input              d_cache_request_busy,
    output     [1:0]   d_cache_request_op,
    output     [3:0]   d_cache_request_sel,
    output     [9:0]   d_cache_request_paddr_lo,
    output     [31:0]  d_cache_request_data,

    // 第二周期
    output     [21:0]  d_cache_request_paddr_hi,

    // 第三周期
    input              d_cache_respond_valid,
    input              d_cache_respond_flush,
    input      [31:0]  d_cache_respond_data,
    output reg         d_cache_request_valid,
    output             d_cache_request_cache
);

wire [1:0] eff_privilege = privilege == 2'h3 && MPRV ? MPP : privilege;

wire        s0_tlb_used;
wire        s0_tlb_index;
wire        s0_pwc_used;
wire        s0_pwc_index;
wire        s0_tp_fill;
wire        s0_fill_src;
wire        s0_pwc_g;
wire        s0_p_fault;
wire [31:0] s0_paddr;

reg         s1_tlb_used;
reg         s1_tlb_index;
reg         s1_pwc_used;
reg         s1_pwc_index;
reg         s1_tp_fill;
reg         s1_fill_src;
reg         s1_pwc_g;
reg         s1_p_fault;
reg  [31:0] s1_paddr;

reg         s1_f_by_va;
reg  [1:0]  s1_op;
reg  [29:0] s1_vaddr;

wire        _s1_op;
wire        _s1_tp_fill;
wire        s1_a_fault;
wire        s1_cache;

reg         s2_tlb_used;
reg         s2_tlb_index;
reg         s2_pwc_used;
reg         s2_pwc_index;
reg         s2_f_by_va;
reg         s2_a_fault;
reg         s2_p_fault;
reg         s2_cache;
reg  [29:0] s2_vaddr;
reg         s2_tp_fill;
reg         s2_fill_src;
reg         s2_sfence;
reg  [1:0]  s2_op;
reg  [31:0] s2_paddr;
reg         s2_pwc_g;

reg s_wait;

always @(posedge clk) begin
    if (!s_wait) begin
        s1_tlb_used  <= s0_tlb_used;
        s1_tlb_index <= s0_tlb_index;
        s1_pwc_used  <= s0_pwc_used;
        s1_pwc_index <= s0_pwc_index;
        s1_tp_fill   <= s0_tp_fill;
        s1_fill_src  <= s0_fill_src;
        s1_pwc_g     <= s0_pwc_g;
        s1_p_fault   <= s0_p_fault;
        s1_paddr     <= s0_paddr;

        s1_f_by_va   <= d_core_request_f_by_va;
        s1_op        <= d_core_request_op;
        s1_vaddr     <= d_core_request_vaddr;

        s2_tlb_used  <= s1_op[1] ? 1'h0 : s1_tlb_used;
        s2_tlb_index <= s1_tlb_index;
        s2_pwc_used  <= s1_op[1] ? 1'h0 : s1_pwc_used;
        s2_pwc_index <= s1_pwc_index;
        s2_f_by_va   <= s1_f_by_va;
        s2_a_fault   <= s1_op[1] ? 1'h0 : s1_a_fault;
        s2_p_fault   <= s1_op[1] ? 1'h0 : s1_p_fault;
        s2_cache     <= s1_cache;
        s2_vaddr     <= s1_vaddr;
        s2_tp_fill   <= s1_op[1] ? 1'h0 : _s1_tp_fill;
        s2_fill_src  <= s1_fill_src;
        s2_sfence    <= s1_op == 2'h3;
        s2_op        <= s1_op[1] ? s1_op : {1'h0, _s1_op};
        s2_paddr     <= s1_paddr;
        s2_pwc_g     <= s1_pwc_g;
    end
end

reg tlb_we;
reg pwc_we;

reg flush;

d_translate u_d_translate (
    .clk         (clk),
    .rst_n       (rst_n),

    .s2_tlb_used (s2_tlb_used & d_core_request_valid),
    .s2_tlb_index(s2_tlb_index),
    .s2_tlb_addr (s2_vaddr[13:10]),
    .s2_pwc_used (s2_pwc_used & d_core_request_valid),
    .s2_pwc_index(s2_pwc_index),
    .s2_pwc_addr (s2_vaddr[21:20]),

    .flush       (flush),
    .f_by_va     (s2_f_by_va),
    .f_va        (s2_vaddr[29:10]),

    .tlb_we      (tlb_we),
    .tlb_waddr   (s2_vaddr[13:10]),
    .tlb_in      (d_cache_respond_data),
    .tlb_tag_in  ({s2_vaddr[29:14], satp[30:22], s2_pwc_g}),

    .pwc_we      (pwc_we),
    .pwc_waddr   (s2_vaddr[21:20]),
    .pwc_in      (d_cache_respond_data),
    .pwc_tag_in  ({s2_vaddr[29:22], satp[30:22]}),

    .MXR         (MXR),
    .SUM         (SUM),
    .privilege   (eff_privilege),
    .satp        (satp),

    .op          (d_core_request_op[0]),
    .vaddr       (d_core_request_vaddr),
    .s0_tlb_used (s0_tlb_used),
    .s0_tlb_index(s0_tlb_index),
    .s0_pwc_used (s0_pwc_used),
    .s0_pwc_index(s0_pwc_index),
    .s0_tp_fill  (s0_tp_fill),
    .s0_fill_src (s0_fill_src),
    .s0_pwc_g    (s0_pwc_g),
    .s0_p_fault  (s0_p_fault),
    .s0_paddr    (s0_paddr)
);

d_paddr_check u_d_paddr_check (
    .clk         (clk),

    .privilege   (eff_privilege),
    .pmpaddr0    (pmpaddr0),
    .pmpaddr1    (pmpaddr1),
    .pmpaddr2    (pmpaddr2),
    .pmpaddr3    (pmpaddr3),
    .pmpcfg0     (pmpcfg0),

    .op          (s1_op[0]),
    .tp_fill     (s1_tp_fill),
    .paddr       (s1_paddr),
    .s1_op       (_s1_op),
    .s1_tp_fill  (_s1_tp_fill),
    .s1_a_fault  (s1_a_fault),
    .s1_cache    (s1_cache)
);

reg d_cache_src_switch;
reg d_cache_src; // 0: 正常读写  1: 读页表项

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_cache_src <= 1'h0;
    end
    else if (d_cache_src_switch) begin
        d_cache_src <= ~d_cache_src;
    end
end

assign d_cache_request_op       = d_cache_src ? 2'h0 : d_core_request_op;
assign d_cache_request_sel      = d_core_request_sel;
assign d_cache_request_paddr_lo = d_cache_src ? s2_paddr[9:0] : d_core_request_vaddr[9:0];
assign d_cache_request_data     = d_core_request_data;
assign d_cache_request_paddr_hi = d_cache_src ? s2_paddr[31:10] : s1_paddr[31:10];
assign d_cache_request_cache    = s2_cache;


reg t_set;
reg t;
always @(posedge clk) begin
    if (t_set) begin
        t <= 1'h1;
    end
    else if (t != 1'h0) begin
        t <= 1'h0;
    end
end

// #region 状态机
reg [1:0] nxt_status;

localparam IDLE    = 2'h0; // 处理普通读写和不缓存读写
localparam WAIT1   = 2'h1; // 填表
localparam WAIT2   = 2'h2; // 填表
localparam FLUSH   = 2'h3; // sfence

reg [1:0] status;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= IDLE;
    end
    else begin
        status <= nxt_status;
    end
end
// #endregion


always @(*) begin
    d_core_request_busy    = d_cache_request_busy;
    d_core_respond_valid   = 1'h0;
    d_core_respond_flush   = d_cache_respond_flush;
    d_core_respond_a_fault = s2_a_fault;
    d_core_respond_p_fault = s2_p_fault;
    d_core_respond_data    = d_cache_respond_data;
    i_mmu_request_flush    = 1'h0;
    i_mmu_request_f_by_va  = s2_f_by_va;
    i_mmu_request_vaddr    = s2_vaddr[29:10];
    d_cache_request_valid  = 1'h0;
    s_wait                 = 1'h0;
    tlb_we                 = 1'h0;
    pwc_we                 = 1'h0;
    flush                  = 1'h0;
    d_cache_src_switch     = 1'h0;
    t_set                  = 1'h0;
    nxt_status             = IDLE;
    case (status)
        IDLE: begin
            if (d_core_request_valid) begin
                if (s2_sfence) begin
                    // d_cache_valid = 0
                    nxt_status = FLUSH;
                    s_wait = 1'h1;
                end
                else if (s2_tp_fill) begin
                    // valid = 0, flush = 1
                    // 下一拍开始请求 d_cache
                    nxt_status = WAIT1;
                    d_core_request_busy = 1'h1;
                    d_core_respond_flush = 1'h1;
                    d_cache_src_switch = 1'h1;
                    s_wait = 1'h1;
                end
                else if (s2_a_fault || s2_p_fault) begin
                    nxt_status = IDLE;
                    d_core_respond_valid = 1'h1;
                end
                else begin
                    // 正常请求 d_cache
                    // 如果 flush = 1，传递到下侧
                    // 可能需要等
                    nxt_status = IDLE;
                    d_cache_request_valid = 1'h1;
                    d_core_respond_valid = d_cache_respond_valid;
                    d_core_respond_flush = d_cache_respond_flush;
                    if (!d_cache_respond_valid && !d_cache_respond_flush) begin
                        s_wait = 1'h1;
                    end
                end
            end
            else begin
                nxt_status = IDLE;
            end
        end
        WAIT1: begin
            s_wait = 1'h1;
            d_core_request_busy = 1'h1;
            if (!d_cache_request_busy) begin
                nxt_status = WAIT2;
                t_set = 1'h1;
            end
            else begin
                nxt_status = WAIT1;
            end
        end
        WAIT2: begin
            s_wait = 1'h1;
            d_core_request_busy = 1'h1;
            if (t != 1'h0) begin
                nxt_status = WAIT2;
            end
            else begin
                d_cache_request_valid = 1'h1;
                if (d_cache_respond_valid) begin
                    nxt_status = IDLE;
                    d_cache_src_switch = 1'h1;
                    if (s2_fill_src) begin
                        pwc_we = 1'h1;
                    end
                    else begin
                        tlb_we = 1'h1;
                    end
                end
                else if (d_cache_respond_flush) begin
                    nxt_status = WAIT1;
                end
                else begin
                    nxt_status = WAIT2;
                end
            end
        end
        FLUSH: begin
            // 请求 i_mmu, ready 时 flush 并进入 IDLE
            s_wait = 1'h1;
            i_mmu_request_flush = 1'h1;
            if (i_mmu_respond_ready) begin
                nxt_status = IDLE;
                d_core_respond_flush = 1'h1;
                d_core_respond_valid = 1'h1;
                flush = 1'h1;
            end
            else begin
                nxt_status = FLUSH;
            end
        end
        default: ;
    endcase
end

endmodule
