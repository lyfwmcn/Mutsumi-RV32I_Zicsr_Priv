`timescale 1ns / 1ns

module uncore (
    input              clk,
    input              rst_n,

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

    input      [1:0]   d_core_request_op,
    // 0: R  1: W  2: sfence.vma  3: fence.i
    input      [3:0]   d_core_request_be,    // [0] 在 op = 2 意为 vaddr 是否有效
    input      [29:0]  d_core_request_vaddr, // 高 30 位虚拟地址
    input      [31:0]  d_core_request_data,
    output reg         d_core_request_busy,

    input              d_core_request_valid,
    output reg         d_core_respond_flush,
    output reg         d_core_respond_access_fault,
    output reg         d_core_respond_page_fault,
    output reg         d_core_respond_valid,
    output reg [31:0]  d_core_respond_data,

    input              i_core_request_valid,
    input      [29:0]  i_core_request_vaddr, // 高 30 位虚拟地址
    output reg         i_core_request_busy,

    output reg         i_core_respond_access_fault,
    output reg         i_core_respond_page_fault,
    output reg         i_core_respond_valid,
    output reg [31:0]  i_core_respond_data,

    // ram 通信
    input              d_ram_request_busy,
    input              d_ram_respond_valid,
    input      [15:0]  d_ram_respond_data,
    output reg         d_ram_request_valid,
    output reg         d_ram_request_we,
    output reg [15:0]  d_ram_request_be,
    output reg [31:0]  d_ram_request_addr,
    output reg [127:0] d_ram_request_data,

    input              i_ram_request_busy,
    input              i_ram_respond_valid,
    input      [15:0]  i_ram_respond_data,
    output reg         i_ram_request_valid,
    output reg [31:0]  i_ram_request_addr
);

wire        s1_tlb_pwc_fill;
wire        s1_fill_src;
wire        s1_page_fault;
wire [1:0]  s1_privilege;
wire [31:0] s1_paddr;
wire [31:0] s1_pte_paddr;

reg  [1:0]  s1_op;
reg  [31:0] s1_pmpaddr0;
reg  [31:0] s1_pmpaddr1;
reg  [31:0] s1_pmpaddr2;
reg  [31:0] s1_pmpaddr3;
reg  [31:0] s1_pmpcfg0;

wire        s2_access_fault;
wire        s2_cached;

reg         s2_tlb_pwc_fill;
reg         s2_fill_src;
reg         s2_page_fault;
reg  [1:0]  s2_op;
reg  [31:0] s2_paddr;
reg  [31:0] s2_pte_paddr;

always @(posedge clk) begin
    s1_op           <= d_core_request_op;
    s1_pmpaddr0     <= pmpaddr0;
    s1_pmpaddr1     <= pmpaddr1;
    s1_pmpaddr2     <= pmpaddr2;
    s1_pmpaddr3     <= pmpaddr3;
    s1_pmpcfg0      <= pmpcfg0;
    s2_page_fault   <= s1_page_fault;
    s2_op           <= s1_op;
    s2_tlb_pwc_fill <= s1_tlb_pwc_fill;
    s2_fill_src     <= s1_fill_src;
    s2_paddr        <= s1_paddr;
    s2_pte_paddr    <= s1_pte_paddr;
end

d_translate u_d_translate (
    .clk              (clk),
    .rst_n            (rst_n),

    .exec             (),

    .flush            (),
    .flush_vaddr_valid(),
    .flush_vaddr      (),

    .tlb_we           (),
    .tlb_waddr        (),
    .tlb_in           (),
    .tlb_tag_in       (),

    .pwc_we           (),
    .pwc_waddr        (),
    .pwc_in           (),
    .pwc_tag_in       (),

    .MPRV             (MPRV),
    .MXR              (MXR),
    .SUM              (SUM),
    .MPP              (MPP),
    .privilege        (privilege),
    .satp             (satp),

    .op               (d_core_request_op[0]),
    .vaddr            (d_core_request_vaddr),
    .tlb_pwc_fill     (s1_tlb_pwc_fill),
    .fill_src         (s1_fill_src),
    .page_fault       (s1_page_fault),
    ._privilege       (s1_privilege),
    .paddr            (s1_paddr),
    .pte_paddr        (s1_pte_paddr)
);

d_paddr_check u_d_paddr_check (
    .clk          (clk),

    .privilege    (s1_privilege),
    .pmpaddr0     (s1_pmpaddr0),
    .pmpaddr1     (s1_pmpaddr1),
    .pmpaddr2     (s1_pmpaddr2),
    .pmpaddr3     (s1_pmpaddr3),
    .pmpcfg0      (s1_pmpcfg0),

    .op           (s1_op[0]),
    .tlb_pwc_fill (s1_tlb_pwc_fill),
    .paddr        (s1_paddr),
    .access_fault (s2_access_fault),
    .cached       (s2_cached)
);

reg d_cache_src;

// #region 状态机
reg [2:0] nxt_status;

localparam IDLE   = 3'h0; // 处理普通读写和不缓存读写
localparam D_WAIT = 3'h1; // 

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
    case (status)
        IDLE: begin
            if (d_core_request_valid) begin
                
            end
        end
        default: ;
    endcase
end

endmodule
