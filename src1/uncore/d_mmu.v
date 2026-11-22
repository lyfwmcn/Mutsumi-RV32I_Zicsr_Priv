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
    output reg [29:0]  i_mmu_request_vaddr,

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

wire        s1_tlb_pwc_fill;
wire        s1_fill_src;
wire        s1_p_fault;
wire [1:0]  s1_privilege;
wire [31:0] s1_paddr;

reg  [1:0]  s1_op;
reg  [31:0] s1_pmpaddr0;
reg  [31:0] s1_pmpaddr1;
reg  [31:0] s1_pmpaddr2;
reg  [31:0] s1_pmpaddr3;
reg  [31:0] s1_pmpcfg0;

wire        s2_a_fault;
wire        s2_cache;

reg         s2_tlb_pwc_fill;
reg         s2_fill_src;
reg         s2_p_fault;
reg         s2_sfence;
reg  [1:0]  s2_op;
reg  [31:0] s2_paddr;

always @(posedge clk) begin
    s1_op           <= d_core_request_op;
    s1_pmpaddr0     <= pmpaddr0;
    s1_pmpaddr1     <= pmpaddr1;
    s1_pmpaddr2     <= pmpaddr2;
    s1_pmpaddr3     <= pmpaddr3;
    s1_pmpcfg0      <= pmpcfg0;
    s2_p_fault      <= s1_p_fault;
    s2_sfence       <= s1_op == 2'h3;
    s2_op           <= s1_op == 2'h3 ? 2'h0 : s1_op;
    s2_tlb_pwc_fill <= s1_tlb_pwc_fill;
    s2_fill_src     <= s1_fill_src;
    s2_paddr        <= s1_paddr;
end

d_translate u_d_translate (
    .clk         (clk),
    .rst_n       (rst_n),

    .valid       (),

    .flush       (),
    .f_by_va     (),
    .f_va        (),

    .tlb_we      (),
    .tlb_waddr   (),
    .tlb_in      (),
    .tlb_tag_in  (),

    .pwc_we      (),
    .pwc_waddr   (),
    .pwc_in      (),
    .pwc_tag_in  (),

    .MPRV        (MPRV),
    .MXR         (MXR),
    .SUM         (SUM),
    .MPP         (MPP),
    .privilege   (privilege),
    .satp        (satp),

    .op          (d_core_request_op[0]),
    .vaddr       (d_core_request_vaddr),
    .tlb_pwc_fill(s1_tlb_pwc_fill),
    .fill_src    (s1_fill_src),
    .p_fault     (s1_p_fault),
    ._privilege  (s1_privilege),
    .paddr       (s1_paddr)
);

d_paddr_check u_d_paddr_check (
    .clk         (clk),

    .privilege   (s1_privilege),
    .pmpaddr0    (s1_pmpaddr0),
    .pmpaddr1    (s1_pmpaddr1),
    .pmpaddr2    (s1_pmpaddr2),
    .pmpaddr3    (s1_pmpaddr3),
    .pmpcfg0     (s1_pmpcfg0),

    .op          (s1_op[0]),
    .tlb_pwc_fill(s1_tlb_pwc_fill),
    .paddr       (s1_paddr),
    .a_fault     (s2_a_fault),
    .cache       (s2_cache)
);

reg d_cache_src; // 0: 正常读写  1: 读页表项

assign d_cache_request_op       = d_cache_src ? 2'h0 : d_core_request_op;
assign d_cache_request_sel      = d_core_request_sel;
assign d_cache_request_paddr_lo = d_cache_src ? s2_paddr[9:0] : d_core_request_vaddr[9:0];
assign d_cache_request_data     = d_core_request_data;
assign d_cache_request_paddr_hi = d_cache_src ? s2_paddr[31:10] : s1_paddr[31:10];
assign d_cache_request_cache    = s2_cache;


// #region 状态机
reg [2:0] nxt_status;

localparam IDLE    = 3'h0; // 处理普通读写和不缓存读写
localparam WAIT1   = 3'h1; // 持续两周期，填表前固定等待阶段
localparam WAIT2   = 3'h2; // 保持 valid = 1，等待回复
localparam FLUSH   = 3'h3; // sfence

reg [2:0] status;
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
    d_core_respond_flush   = 1'h0;
    d_core_respond_a_fault = 1'h0;
    d_core_respond_p_fault = 1'h0;
    d_core_respond_data    = 32'h0;
    i_mmu_request_flush    = 1'h0;
    i_mmu_request_f_by_va  = 1'h0;
    i_mmu_request_vaddr    = 30'h0;
    d_cache_request_valid  = 1'h0;
    nxt_status             = IDLE;
    case (status)
        IDLE: begin
            if (d_core_request_valid) begin
                if (s2_tlb_pwc_fill) begin
                    // valid = 0, flush = 1
                    // 下一拍开始请求 d_cache
                end
                else if (s2_sfence) begin
                    nxt_status = FLUSH;
                    // valid = 0, flush = 1
                    // d_cache_valid = 0
                end
                else begin
                    // 正常请求 d_cache
                    // 如果 flush = 1，传递到下侧
                    // 可能需要等
                end
            end
            else begin
                nxt_status = IDLE;
            end
        end
        WAIT1: begin
            // 保持 busy = 1
        end
        WAIT2: begin
            // 保持 busy = 1
        end
        FLUSH: begin
            // 保持 busy = 1
            // 请求 i_mmu, ready 时 flush 并进入 IDLE
        end
        default: ;
    endcase
end

endmodule
