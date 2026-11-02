`timescale 1ns / 1ns

module uncore (
    input              clk,
    input              rst_n,

    input       [1:0]  privilege,
    input       [31:0] satp,

    // 流水线相关接口
    input              d_core_request_valid,
    // 0: R  1: W  2: sfence.vma  3: fence.i
    input      [1:0]   d_core_request_op,
    input      [3:0]   d_core_request_be,
    input      [29:0]  d_core_request_vaddr, // 高 30 位虚拟地址
    input      [31:0]  d_core_request_data,
    output reg         d_core_request_busy,
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

    // sdram 通信
    input              d_ram_request_busy,
    input              d_ram_respond_valid,
    input      [15:0]  d_ram_respond_data,
    output reg         d_ram_request_valid,
    output reg         d_ram_request_we,
    output reg [15:0]  d_ram_request_be,
    output reg [32:0]  d_ram_request_addr,
    output reg [127:0] d_ram_request_data,

    input              i_ram_request_busy,
    input              i_ram_respond_valid,
    input      [15:0]  i_ram_respond_data,
    output reg         i_ram_request_valid,
    output reg [32:0]  i_ram_request_addr
);

// #region 状态机
reg       i1_next_status;
reg [3:0] i2_next_status;
reg [4:0] d_next_status;
// 组合逻辑接口


localparam I1_IDLE   = 1'h0;
localparam I1_LOOKUP = 1'h1; // read
reg       i1_status;

localparam I2_JUDGE1      = 4'h0; // paddr, 3i_cache_hit, 3i_cache_index, i_tlb_hit, i_tlb_pte, i_pwc_hit, i_pwc_pte, i_pwc_npte 尝试提前算
localparam I2_JUDGE2      = 4'h1;
localparam I2_PWC_SEND    = 4'h2;
localparam I2_PWC_GET     = 4'h3; // pwc_w, pwc_tag_w
localparam I2_PWC_FILL    = 4'h4; // pwc_w
localparam I2_TLB_SEND    = 4'h5;
localparam I2_TLB_GET     = 4'h6; // tlb_w, tlb_tag_w
localparam I2_TLB_FILL    = 4'h7; // tlb_w
localparam I2_MODIFY_A1   = 4'h8; // pwc_w, tlb_w
localparam I2_MODIFY_A2   = 4'h9;
localparam I2_UPDATE      = 4'ha; // read
localparam I2_CACHE_SEND  = 4'hb;
localparam I2_CACHE_GET   = 4'hc; // cache_w, cache_tag_w
localparam I2_CACHE_FILL  = 4'hd; // cache_w
localparam I2_FREE        = 4'he;
reg [3:0] i2_status;

localparam D_IDLE        = 5'h0;
localparam D_LOOKUP      = 5'h1;
localparam D_JUDGE1      = 5'h2;
localparam D_JUDGE2      = 5'h3;
localparam D_PWC_SEND    = 5'h4;
localparam D_PWC_GET     = 5'h5;
localparam D_PWC_FILL    = 5'h6;
localparam D_TLB_SEND    = 5'h7;
localparam D_TLB_GET     = 5'h8;
localparam D_TLB_FILL    = 5'h9;
localparam D_AD_READ     = 5'ha;
localparam D_AD_SEND     = 5'hb;
localparam D_AD_GET      = 5'hc;
localparam D_AD_FILL     = 5'hd;
localparam D_UPDATE      = 5'he;
localparam D_CACHE_WB    = 5'hf;
localparam D_CACHE_SEND  = 5'h10;
localparam D_CACHE_GET   = 5'h11;
localparam D_CACHE_FILL  = 5'h12;
localparam D_RWT_SEND    = 5'h13;
localparam D_RWT_GET     = 5'h14;
localparam D_RWT_FILL    = 5'h15;
localparam D_AD_I_READ   = 5'h16;
localparam D_AD_I_SEND   = 5'h17;
localparam D_AD_I_GET    = 5'h18;
localparam D_AD_I_FILL   = 5'h19;
localparam D_FENCE       = 5'h1a;
localparam D_F_SCAN      = 5'h1b;
localparam D_F_WORK      = 5'h1c;
localparam D_F_DONE      = 5'h1d;
reg [4:0] d_status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i1_status <= I1_IDLE;
        i2_status <= I2_JUDGE1;
        d_status  <= D_IDLE;
    end
    else begin
        i1_status <= i1_next_status;
        i2_status <= i2_next_status;
        d_status  <= d_next_status;
    end
end
// #endregion



// #region 响应区域
reg        nxt_d_core_respond_access_fault;
reg        nxt_d_core_respond_page_fault;
reg        nxt_d_core_respond_valid;
reg [31:0] nxt_d_core_respond_data;
reg        nxt_i_core_respond_access_fault;
reg        nxt_i_core_respond_page_fault;
reg        nxt_i_core_respond_valid;
reg [31:0] nxt_i_core_respond_data;
// 组合逻辑接口


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_core_respond_valid <= 1'h0;
        i_core_respond_valid <= 1'h0;
    end
    else begin
        d_core_respond_access_fault <= nxt_d_core_respond_access_fault;
        d_core_respond_page_fault <= nxt_d_core_respond_page_fault;
        d_core_respond_valid <= nxt_d_core_respond_valid;
        d_core_respond_data <= nxt_d_core_respond_data;
        i_core_respond_access_fault <= nxt_i_core_respond_access_fault;
        i_core_respond_page_fault <= nxt_i_core_respond_page_fault;
        i_core_respond_valid <= nxt_i_core_respond_valid;
        i_core_respond_data <= nxt_i_core_respond_data;
    end
end
// #endregion



// #region i-cache, i-tlb, i-pwc 缓存
reg  [1:0]   i_privilege_in;
reg  [31:0]  i_satp_in;

reg          i_re;
reg          i_cache_flush;
reg          i_pwc_tlb_flush;
reg  [29:0]  i_vaddr_in;

wire [31:0]  i_cache_out     [3:0];
wire [24:0]  i_cache_tag_out [3:0];

wire [31:0]  i_pwc_out;
wire [17:0]  i_pwc_tag_out;

wire [31:0]  i_tlb_out;
wire [47:0]  i_tlb_tag_out;

wire         i_cache_hit0;
wire         i_cache_hit1;
wire         i_cache_hit2;
wire [1:0]   i_cache_index0;
wire [1:0]   i_cache_index1;
wire [1:0]   i_cache_index2;
wire         i_pwc_hit;
wire         i_pwc_pte;
wire         i_pwc_npte;
wire         i_tlb_hit;
wire         i_tlb_pte;

reg  [3:0]   i_cache_be;
reg  [31:0]  i_cache_in;
reg  [1:0]   i_cache_windex;
reg  [7:0]   i_cache_waddr;    // 以 4B 为单位的地址

reg          i_cache_tag_we;
reg  [24:0]  i_cache_tag_in;
reg  [1:0]   i_cache_tag_windex;
reg  [5:0]   i_cache_tag_waddr;    // 以 4B 为单位的地址

reg  [3:0]   i_pwc_be;
reg  [31:0]  i_pwc_in;
reg  [1:0]   i_pwc_waddr;
reg          i_pwc_tag_we;
reg  [17:0]  i_pwc_tag_in;

reg  [3:0]   i_tlb_be;
reg  [31:0]  i_tlb_in;
reg  [4:0]   i_tlb_waddr;
reg          i_tlb_tag_we;
reg  [47:0]  i_tlb_tag_in;
reg  [2:0]   i_tlb_tag_waddr;
// 组合逻辑接口


i_cache_ram i_cache_ram (
    .clk  (clk),
    .rst_n(rst_n),

    .privilege(i_privilege_in),
    .satp     (i_satp_in),

    .re             (i_re),
    .i_cache_flush  (i_cache_flush),
    .i_pwc_tlb_flush(i_pwc_tlb_flush),
    .vaddr          (i_vaddr_in),

    .i_cache_out0(i_cache_out[0]),
    .i_cache_out1(i_cache_out[1]),
    .i_cache_out2(i_cache_out[2]),
    .i_cache_out3(i_cache_out[3]),

    .i_cache_tag_out0(i_cache_tag_out[0]),
    .i_cache_tag_out1(i_cache_tag_out[1]),
    .i_cache_tag_out2(i_cache_tag_out[2]),
    .i_cache_tag_out3(i_cache_tag_out[3]),

    .i_pwc_out    (i_pwc_out),
    .i_pwc_tag_out(i_pwc_tag_out),

    .i_tlb_out    (i_tlb_out),
    .i_tlb_tag_out(i_tlb_tag_out),

    .i_cache_hit0  (i_cache_hit0),
    .i_cache_hit1  (i_cache_hit1),
    .i_cache_hit2  (i_cache_hit2),
    .i_cache_index0(i_cache_index0),
    .i_cache_index1(i_cache_index1),
    .i_cache_index2(i_cache_index2),
    .i_pwc_hit     (i_pwc_hit),
    .i_pwc_pte     (i_pwc_pte),
    .i_pwc_npte    (i_pwc_npte),
    .i_tlb_hit     (i_tlb_hit),
    .i_tlb_pte     (i_tlb_pte),

    .i_cache_be    (i_cache_be),
    .i_cache_in    (i_cache_in),
    .i_cache_windex(i_cache_windex),
    .i_cache_waddr (i_cache_waddr),

    .i_cache_tag_we    (i_cache_tag_we),
    .i_cache_tag_in    (i_cache_tag_in),
    .i_cache_tag_windex(i_cache_tag_windex),
    .i_cache_tag_waddr (i_cache_tag_waddr),

    .i_pwc_be    (i_pwc_be),
    .i_pwc_in    (i_pwc_in),
    .i_pwc_waddr (i_pwc_waddr),
    .i_pwc_tag_we(i_pwc_tag_we),
    .i_pwc_tag_in(i_pwc_tag_in),

    .i_tlb_be       (i_tlb_be),
    .i_tlb_in       (i_tlb_in),
    .i_tlb_waddr    (i_tlb_waddr),
    .i_tlb_tag_we   (i_tlb_tag_we),
    .i_tlb_tag_in   (i_tlb_tag_in),
    .i_tlb_tag_waddr(i_tlb_tag_waddr)
);
// #endregion



// #region i1, i2 间请求缓存
reg i2_push;
reg i2_pop;
// 组合逻辑接口


reg        i_valid;
reg [1:0]  i_privilege;
reg [31:0] i_satp;
reg [29:0] i_vaddr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i_valid <= 1'h0;
    end
    else begin
        if (i2_pop) begin
            i_valid <= 1'h0;
        end
        if (i2_push) begin
            i_valid     <= 1'h1;
            i_privilege <= saved_i_core_request_privilege;
            i_satp      <= saved_i_core_request_satp;
            i_vaddr     <= saved_i_core_request_vaddr;
        end
    end
end
// #endregion



// #region d-cache, d-tlb, d-pwc 缓存
reg          d_op_in;
reg  [1:0]   d_privilege_in;
reg  [31:0]  d_satp_in;

reg          d_re;
reg          d_cache_flush;
reg          d_pwc_tlb_flush;
reg  [31:0]  d_addr_in; // 也可传递物理地址

wire [31:0]  d_cache_out [3:0];
wire [127:0] d_cache_line_out [3:0];
wire [25:0]  d_cache_tag_out [3:0];

wire [31:0]  d_pwc_out;
wire [17:0]  d_pwc_tag_out;

wire [31:0]  d_tlb_out;
wire [47:0]  d_tlb_tag_out;

wire         d_cache_hit0;
wire         d_cache_hit1;
wire         d_cache_hit2;
wire         d_cache_hit3;
wire [1:0]   d_cache_index0;
wire [1:0]   d_cache_index1;
wire [1:0]   d_cache_index2;
wire [1:0]   d_cache_index3;
wire         d_pwc_hit;
wire         d_pwc_pte;
wire         d_pwc_npte;
wire         d_tlb_hit;
wire         d_tlb_pte;

reg  [3:0]   d_cache_be;
reg  [31:0]  d_cache_in;
reg  [1:0]   d_cache_windex;
reg  [7:0]   d_cache_waddr;    // 以 4B 为单位的地址

reg          d_cache_tag_we;
reg  [25:0]  d_cache_tag_in;
reg  [1:0]   d_cache_tag_windex;
reg  [5:0]   d_cache_tag_waddr;    // 以 4B 为单位的地址

reg  [3:0]   d_pwc_be;
reg  [31:0]  d_pwc_in;
reg  [1:0]   d_pwc_waddr;
reg          d_pwc_tag_we;
reg  [17:0]  d_pwc_tag_in;

reg  [3:0]   d_tlb_be;
reg  [31:0]  d_tlb_in;
reg  [4:0]   d_tlb_waddr;
reg          d_tlb_tag_we;
reg  [47:0]  d_tlb_tag_in;
reg  [2:0]   d_tlb_tag_waddr;
// 组合逻辑接口


d_cache_ram u_d_cache_ram (
    .clk  (clk),
    .rst_n(rst_n),

    .op       (d_op_in),
    .privilege(d_privilege_in),
    .satp     (d_satp_in),

    .re             (d_re),
    .d_cache_flush  (d_cache_flush),
    .d_pwc_tlb_flush(d_pwc_tlb_flush),
    .addr           (d_addr_in),

    .d_cache_out0(d_cache_out[0]),
    .d_cache_out1(d_cache_out[1]),
    .d_cache_out2(d_cache_out[2]),
    .d_cache_out3(d_cache_out[3]),

    .d_cache_line_out0(d_cache_line_out[0]),
    .d_cache_line_out1(d_cache_line_out[1]),
    .d_cache_line_out2(d_cache_line_out[2]),
    .d_cache_line_out3(d_cache_line_out[3]),

    .d_cache_tag_out0(d_cache_tag_out[0]),
    .d_cache_tag_out1(d_cache_tag_out[1]),
    .d_cache_tag_out2(d_cache_tag_out[2]),
    .d_cache_tag_out3(d_cache_tag_out[3]),

    .d_pwc_out    (d_pwc_out),
    .d_pwc_tag_out(d_pwc_tag_out),

    .d_tlb_out    (d_tlb_out),
    .d_tlb_tag_out(d_tlb_tag_out),

    .d_cache_hit0  (d_cache_hit0),
    .d_cache_hit1  (d_cache_hit1),
    .d_cache_hit2  (d_cache_hit2),
    .d_cache_hit3  (d_cache_hit3),
    .d_cache_index0(d_cache_index0),
    .d_cache_index1(d_cache_index1),
    .d_cache_index2(d_cache_index2),
    .d_cache_index3(d_cache_index3),
    .d_pwc_hit     (d_pwc_hit),
    .d_pwc_pte     (d_pwc_pte),
    .d_pwc_npte    (d_pwc_npte),
    .d_tlb_hit     (d_tlb_hit),
    .d_tlb_pte     (d_tlb_pte),

    .d_cache_be    (d_cache_be),
    .d_cache_in    (d_cache_in),
    .d_cache_windex(d_cache_windex),
    .d_cache_waddr (d_cache_waddr),

    .d_cache_tag_we    (d_cache_tag_we),
    .d_cache_tag_in    (d_cache_tag_in),
    .d_cache_tag_windex(d_cache_tag_windex),
    .d_cache_tag_waddr (d_cache_tag_waddr),

    .d_pwc_be    (d_pwc_be),
    .d_pwc_in    (d_pwc_in),
    .d_pwc_waddr (d_pwc_waddr),
    .d_pwc_tag_we(d_pwc_tag_we),
    .d_pwc_tag_in(d_pwc_tag_in),

    .d_tlb_be       (d_tlb_be),
    .d_tlb_in       (d_tlb_in),
    .d_tlb_waddr    (d_tlb_waddr),
    .d_tlb_tag_we   (d_tlb_tag_we),
    .d_tlb_tag_in   (d_tlb_tag_in),
    .d_tlb_tag_waddr(d_tlb_tag_waddr)
);
// #endregion



// #region d 请求缓存
reg d_push;
// 组合逻辑接口


reg [1:0]  d_privilege;
reg [31:0] d_satp;
reg [1:0]  d_op;
reg [3:0]  d_be;
reg [29:0] d_vaddr;
reg [31:0] d_data;

always @(posedge clk) begin
    if (d_push) begin
        d_privilege <= privilege;
        d_satp      <= satp;
        d_op        <= d_core_request_op;
        d_be        <= d_core_request_be;
        d_vaddr     <= d_core_request_vaddr;
        d_data      <= d_core_request_data;
    end
end
// #endregion



// #region i1 请求缓存
reg i1_push;
// 组合逻辑接口


reg [1:0]  saved_i_core_request_privilege;
reg [31:0] saved_i_core_request_satp;
reg [29:0] saved_i_core_request_vaddr;

always @(posedge clk) begin
    if (i1_push) begin
        saved_i_core_request_privilege <= privilege;
        saved_i_core_request_satp      <= satp;
        saved_i_core_request_vaddr     <= i_core_request_vaddr;
    end
end
// #endregion



// #region d-ad 缓存
reg d_ad_save;

reg [31:0] saved_d_tlb_out;
reg [31:0] saved_d_pwc_out;

always @(posedge clk) begin
    if (d_ad_save) begin
        saved_d_tlb_out <= d_tlb_out;
        saved_d_pwc_out <= d_pwc_out;
    end
end
// #endregion



// #region i 侧变量传递
reg        i_save_pwc_or_tlb;
reg        i_save_pte_paddr;
reg        i_save_paddr;

reg        nxt_i_pwc_or_tlb;
reg [31:0] nxt_i_pte_paddr;
reg [31:0] nxt_i_paddr;
// 组合逻辑接口


reg        i_pwc_or_tlb;
reg [31:0] i_pte_paddr;
reg [31:0] i_paddr;

always @(posedge clk) begin
    if (i_save_pwc_or_tlb) begin
        i_pwc_or_tlb <= nxt_i_pwc_or_tlb;
    end
    if (i_save_pte_paddr) begin
        i_pte_paddr <= nxt_i_pte_paddr;
    end
    if (i_save_paddr) begin
        i_paddr <= nxt_i_paddr;
    end
end
// #endregion



// #region d 侧变量传递
reg        d_save_pwc_or_tlb;
reg        d_save_set_d;
reg        d_save_pte_paddr;
reg        d_save_paddr;
reg        d_save_ireturn;

reg        nxt_d_pwc_or_tlb;
reg        nxt_d_set_d;
reg [31:0] nxt_d_pte_paddr;
reg [31:0] nxt_d_paddr;
reg        nxt_d_ireturn;
// 组合逻辑接口


reg        d_pwc_or_tlb;
reg        d_set_d;
reg [31:0] d_paddr;
reg [31:0] d_pte_paddr;
reg        d_ireturn;

always @(posedge clk) begin
    if (d_save_pwc_or_tlb) begin
        d_pwc_or_tlb <= nxt_d_pwc_or_tlb;
    end
    if (d_save_ireturn) begin
        d_ireturn <= nxt_d_ireturn;
    end
    if (d_save_paddr) begin
        d_paddr <= nxt_d_paddr;
    end
    if (d_save_pte_paddr) begin
        d_pte_paddr <= nxt_d_pte_paddr;
    end
    if (d_save_set_d) begin
        d_set_d <= nxt_d_set_d;
    end
end
// #endregion



// #region 计时器区域
reg i_t_begin;
reg d_t_begin;
reg d_t1_begin;
reg f_begin;
reg f_add;
// 组合逻辑接口


reg [2:0] i_t;
reg [2:0] d_t;
reg       d_t1;
reg [7:0] f_t;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i_t <= 3'h7;
        d_t <= 3'h7;
        d_t1 <= 1'h1;
        f_t <= 8'h0;
    end
    else begin
        if (i_t_begin) begin
            i_t <= 3'h6;
        end
        else if (i_t != 3'h7) begin
            i_t <= i_t - 3'h1;
        end
        if (d_t_begin) begin
            d_t <= 3'h6;
        end
        else if (d_t != 3'h7) begin
            d_t <= d_t - 3'h1;
        end
        if (d_t1_begin) begin
            d_t1 <= 1'h0;
        end
        else if (d_t1 != 1'h1) begin
            d_t1 <= d_t1 - 1'h1;
        end
        if (f_begin) begin
            f_t <= 8'h0;
        end
        else if (f_add) begin
            f_t <= f_t + 8'h1;
        end
    end
end
// #endregion



// #region 传输缓存区域
reg i_save_low_word;
reg i_save_high_word;
reg d_save_low_word;
reg d_save_high_word;
reg [15:0] nxt_d_low_word;
reg [15:0] nxt_d_high_word;
// 组合逻辑接口


reg [15:0] i_low_word;
reg [15:0] i_high_word;
reg [15:0] d_low_word;
reg [15:0] d_high_word;

always @(posedge clk) begin
    if (i_save_low_word) begin
        i_low_word <= i_ram_respond_data;
    end
    if (i_save_high_word) begin
        i_high_word <= i_ram_respond_data;
    end
    if (d_save_low_word) begin
        d_low_word <= nxt_d_low_word;
    end
    if (d_save_high_word) begin
        d_high_word <= nxt_d_high_word;
    end
end
// #endregion



// #region 组内行选择轮转区域
reg i_add;
reg d_add;
// 组合逻辑接口


reg [1:0] i_ptr;
reg [1:0] d_ptr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i_ptr <= 2'h0;
        d_ptr <= 2'h0;
    end
    else begin
        if (i_add) begin
            i_ptr <= i_ptr + 2'h1;
        end
        if (d_add) begin
            d_ptr <= d_ptr + 2'h1;
        end
    end
end
// #endregion



// #region 函数区
function automatic [1:0] pma;
    input [31:0] paddr;
    begin
        pma = paddr[31:24] != 8'h0 ? 2'h0 :  // 未映射区域
              paddr[23] ? 2'h2 :             // I/D 均不可缓存区域
              paddr[22:10] == 13'h0 ? 2'h3 : // I 可缓存，D 不可缓存区域
              2'h1;                          // I/D 均可缓存区域
    end
endfunction

function automatic i_tlb_a;
    begin
        i_tlb_a = i_tlb_out[6];
    end
endfunction

function automatic i_pwc_a;
    begin
        i_pwc_a = i_pwc_out[6];
    end
endfunction

function automatic d_tlb_a;
    begin
        d_tlb_a = d_tlb_out[6];
    end
endfunction

function automatic d_tlb_d;
    begin
        d_tlb_d = d_tlb_out[7];
    end
endfunction

function automatic d_pwc_a;
    begin
        d_pwc_a = d_pwc_out[6];
    end
endfunction

function automatic d_pwc_d;
    begin
        d_pwc_d = d_pwc_out[7];
    end
endfunction

function automatic [31:0] replace_ad;
    input a;
    input d;
    input [31:0] pte;
    begin
        replace_ad = {pte[31:8], pte[7] | d, pte[6] | a, pte[5:0]};
    end
endfunction

function automatic d_cache_need_wb;
    begin
        d_cache_need_wb = d_cache_tag_out[0][0] && d_cache_tag_out[1][0] &&
                          d_cache_tag_out[2][0] && d_cache_tag_out[3][0] &&
                          d_cache_tag_out[d_ptr][25];
    end
endfunction
// #endregion



// #region 任务区
task automatic i_read(
    input        src,
    input [29:0] vaddr
);
    i_re = 1'h1;
    i_vaddr_in = vaddr;
    i_privilege_in = src ? i_privilege : saved_i_core_request_privilege;
    i_satp_in = src ? i_satp : saved_i_core_request_satp;
endtask

task automatic i_core_respond(
    input access_fault,
    input page_fault,
    input [31:0] data
);
    nxt_i_core_respond_access_fault = access_fault;
    nxt_i_core_respond_page_fault = page_fault;
    nxt_i_core_respond_valid = 1'h1;
    nxt_i_core_respond_data = data;
endtask

task automatic i_ram_request(
    input [32:0] paddr
);
    i_ram_request_valid = 1'h1;
    i_ram_request_addr = paddr;
endtask

task automatic i_pwc_w(
    input [3:0] be,
    input [1:0] addr,
    input [31:0] in
);
    i_pwc_be = be;
    i_pwc_in = in;
    i_pwc_waddr = addr;
endtask

task automatic i_pwc_tag_w(
    input [17:0] in
);
    i_pwc_tag_we = 1'h1;
    i_pwc_tag_in = in;
endtask

task automatic i_tlb_w(
    input [3:0] be,
    input [4:0] addr,
    input [31:0] in
);
    i_tlb_be = be;
    i_tlb_waddr = addr;
    i_tlb_in = in;
endtask

task automatic i_tlb_tag_w(
    input [2:0] addr,
    input [47:0] in
);
    i_tlb_tag_we = 1'h1;
    i_tlb_tag_waddr = addr;
    i_tlb_tag_in = in;
endtask

task automatic i_cache_w(
    input [3:0] be,
    input [7:0] addr,
    input [31:0] in
);
    i_cache_be = be;
    i_cache_waddr = addr;
    i_cache_in = in;
    if (!i_cache_tag_out[0][0]) begin
        i_cache_windex = 2'h0;
    end
    else if (!i_cache_tag_out[1][0]) begin
        i_cache_windex = 2'h1;
    end
    else if (!i_cache_tag_out[2][0]) begin
        i_cache_windex = 2'h2;
    end
    else if (!i_cache_tag_out[3][0]) begin
        i_cache_windex = 2'h3;
    end
    else begin
        i_cache_windex = i_ptr;
    end
endtask

task automatic i_cache_tag_w(
    input [5:0] addr,
    input [24:0] in
);
    i_cache_tag_we = 1'h1;
    i_cache_tag_waddr = addr;
    i_cache_tag_in = in;
    if (!i_cache_tag_out[0][0]) begin
        i_cache_tag_windex = 2'h0;
    end
    else if (!i_cache_tag_out[1][0]) begin
        i_cache_tag_windex = 2'h1;
    end
    else if (!i_cache_tag_out[2][0]) begin
        i_cache_tag_windex = 2'h2;
    end
    else if (!i_cache_tag_out[3][0]) begin
        i_cache_tag_windex = 2'h3;
    end
    else begin
        i_cache_tag_windex = i_ptr;
    end
endtask

task automatic d_read(
    input [31:0] vaddr
);
    d_re = 1'h1;
    d_addr_in = vaddr;
    d_op_in = d_op[0];
    d_privilege_in = d_privilege;
    d_satp_in = d_satp;
endtask

task automatic d_core_respond(
    input access_fault,
    input page_fault,
    input [31:0] data
);
    nxt_d_core_respond_access_fault = access_fault;
    nxt_d_core_respond_page_fault = page_fault;
    nxt_d_core_respond_valid = 1'h1;
    nxt_d_core_respond_data = data;
endtask

task automatic d_ram_request(
    input         we,
    input [15:0]  be,
    input [32:0]  paddr,
    input [127:0] data
);
    d_ram_request_valid = 1'h1;
    d_ram_request_we = we;
    d_ram_request_be = be;
    d_ram_request_addr = paddr;
    d_ram_request_data = data;
endtask

task automatic d_pwc_w(
    input [3:0] be,
    input [1:0] addr,
    input [31:0] in
);
    d_pwc_be = be;
    d_pwc_in = in;
    d_pwc_waddr = addr;
endtask

task automatic d_pwc_tag_w(
    input [17:0] in
);
    d_pwc_tag_we = 1'h1;
    d_pwc_tag_in = in;
endtask

task automatic d_tlb_w(
    input [3:0] be,
    input [4:0] addr,
    input [31:0] in
);
    d_tlb_be = be;
    d_tlb_waddr = addr;
    d_tlb_in = in;
endtask

task automatic d_tlb_tag_w(
    input [2:0] addr,
    input [47:0] in
);
    d_tlb_tag_we = 1'h1;
    d_tlb_tag_waddr = addr;
    d_tlb_tag_in = in;
endtask

task automatic d_cache_w_index(
    input [3:0] be,
    input [1:0] index,
    input [7:0] addr,
    input [31:0] in
);
    d_cache_be = be;
    d_cache_windex = index;
    d_cache_waddr = addr;
    d_cache_in = in;
endtask

task automatic d_cache_tag_w_index(
    input [5:0] addr,
    input [1:0] index,
    input [25:0] in
);
    d_cache_tag_we = 1'h1;
    d_cache_tag_waddr = addr;
    d_cache_tag_in = in;
    d_cache_tag_windex = index;
endtask

task automatic d_cache_w(
    input [3:0] be,
    input [7:0] addr,
    input [31:0] in
);
    d_cache_be = be;
    d_cache_waddr = addr;
    d_cache_in = in;
    if (!d_cache_tag_out[0][0]) begin
        d_cache_windex = 2'h0;
    end
    else if (!d_cache_tag_out[1][0]) begin
        d_cache_windex = 2'h1;
    end
    else if (!d_cache_tag_out[2][0]) begin
        d_cache_windex = 2'h2;
    end
    else if (!d_cache_tag_out[3][0]) begin
        d_cache_windex = 2'h3;
    end
    else begin
        d_cache_windex = d_ptr;
    end
endtask

task automatic d_cache_tag_w(
    input [5:0] addr,
    input [25:0] in
);
    d_cache_tag_we = 1'h1;
    d_cache_tag_waddr = addr;
    d_cache_tag_in = in;
    if (!d_cache_tag_out[0][0]) begin
        d_cache_tag_windex = 2'h0;
    end
    else if (!d_cache_tag_out[1][0]) begin
        d_cache_tag_windex = 2'h1;
    end
    else if (!d_cache_tag_out[2][0]) begin
        d_cache_tag_windex = 2'h2;
    end
    else if (!d_cache_tag_out[3][0]) begin
        d_cache_tag_windex = 2'h3;
    end
    else begin
        d_cache_tag_windex = d_ptr;
    end
endtask
// #endregion



reg i_read_lock;
reg d_finish_i;

always @(*) begin
// #region 默认参数区域
    d_core_request_busy = 1'h1;
    i_core_request_busy = 1'h1;
    d_ram_request_valid = 1'h0;
    d_ram_request_we    = 1'h0;
    d_ram_request_be    = 16'h0;
    d_ram_request_addr  = 33'h0;
    d_ram_request_data  = 128'h0;
    i_ram_request_valid = 1'h0;
    i_ram_request_addr  = 33'h0;

    i1_next_status = I1_IDLE;
    i2_next_status = I2_JUDGE1;
    d_next_status  = D_IDLE;

    nxt_d_core_respond_access_fault = 1'h0;
    nxt_d_core_respond_page_fault   = 1'h0;
    nxt_d_core_respond_valid        = 1'h0;
    nxt_d_core_respond_data         = 32'h0;
    nxt_i_core_respond_access_fault = 1'h0;
    nxt_i_core_respond_page_fault   = 1'h0;
    nxt_i_core_respond_valid        = 1'h0;
    nxt_i_core_respond_data         = 32'h0;

    i_privilege_in     = 2'h0;
    i_satp_in          = 32'h0;
    i_re               = 1'h0;
    i_cache_flush      = 1'h0;
    i_pwc_tlb_flush    = 1'h0;
    i_vaddr_in         = 30'h0;
    i_cache_be         = 4'h0;
    i_cache_in         = 32'h0;
    i_cache_windex     = 2'h0;
    i_cache_waddr      = 8'h0;
    i_cache_tag_we     = 1'h0;
    i_cache_tag_in     = 25'h0;
    i_cache_tag_windex = 2'h0;
    i_cache_tag_waddr  = 6'h0;
    i_pwc_be           = 4'h0;
    i_pwc_in           = 32'h0;
    i_pwc_waddr        = 2'h0;
    i_pwc_tag_we       = 1'h0;
    i_pwc_tag_in       = 18'h0;
    i_tlb_be           = 4'h0;
    i_tlb_in           = 32'h0;
    i_tlb_waddr        = 5'h0;
    i_tlb_tag_we       = 1'h0;
    i_tlb_tag_in       = 48'h0;
    i_tlb_tag_waddr    = 3'h0;

    i2_push = 1'h0;
    i2_pop  = 1'h0;

    d_op_in            = 1'h0;
    d_privilege_in     = 2'h0;
    d_satp_in          = 32'h0;
    d_re               = 1'h0;
    d_cache_flush      = 1'h0;
    d_pwc_tlb_flush    = 1'h0;
    d_addr_in          = 32'h0;
    d_cache_be         = 4'h0;
    d_cache_in         = 32'h0;
    d_cache_windex     = 2'h0;
    d_cache_waddr      = 8'h0;
    d_cache_tag_we     = 1'h0;
    d_cache_tag_in     = 26'h0;
    d_cache_tag_windex = 2'h0;
    d_cache_tag_waddr  = 6'h0;
    d_pwc_be           = 4'h0;
    d_pwc_in           = 32'h0;
    d_pwc_waddr        = 2'h0;
    d_pwc_tag_we       = 1'h0;
    d_pwc_tag_in       = 18'h0;
    d_tlb_be           = 4'h0;
    d_tlb_in           = 32'h0;
    d_tlb_waddr        = 5'h0;
    d_tlb_tag_we       = 1'h0;
    d_tlb_tag_in       = 48'h0;
    d_tlb_tag_waddr    = 3'h0;

    d_push = 1'h0;

    i1_push = 1'h0;

    d_ad_save = 1'h0;

    i_save_pwc_or_tlb = 1'h0;
    i_save_pte_paddr  = 1'h0;
    i_save_paddr      = 1'h0;
    nxt_i_pwc_or_tlb  = 1'h0;
    nxt_i_pte_paddr   = 32'h0;
    nxt_i_paddr       = 32'h0;

    d_save_pwc_or_tlb = 1'h0;
    d_save_set_d      = 1'h0;
    d_save_pte_paddr  = 1'h0;
    d_save_paddr      = 1'h0;
    d_save_ireturn    = 1'h0;
    nxt_d_pwc_or_tlb  = 1'h0;
    nxt_d_set_d       = 1'h0;
    nxt_d_pte_paddr   = 32'h0;
    nxt_d_paddr       = 32'h0;
    nxt_d_ireturn     = 1'h0;

    i_t_begin  = 1'h0;
    d_t_begin  = 1'h0;
    d_t1_begin = 1'h0;
    f_begin    = 1'h0;
    f_add      = 1'h0;

    i_save_low_word  = 1'h0;
    i_save_high_word = 1'h0;
    d_save_low_word  = 1'h0;
    d_save_high_word = 1'h0;
    nxt_d_low_word   = 16'h0;
    nxt_d_high_word  = 16'h0;

    i_add = 1'h0;
    d_add = 1'h0;

    i_read_lock = 1'h1;
    d_finish_i  = 1'h0;
// #endregion
    case (d_status)
        D_IDLE: begin
            if (i2_status == I2_MODIFY_A2) begin
                d_core_request_busy = 1'h1;
                d_next_status = D_AD_I_READ;
                d_save_ireturn = 1'h1;
                nxt_d_ireturn = 1'h0;
            end
            else begin
                d_core_request_busy = 1'h0;
                if (d_core_request_valid) begin
                    d_push = 1'h1;
                    d_next_status = D_LOOKUP;
                end
                else begin
                    d_next_status = D_IDLE;
                end
            end
        end
        D_LOOKUP: begin
            case (d_op)
                2'h0, 2'h1: begin
                    d_next_status = D_JUDGE1;
                    d_read({2'h0, d_vaddr});
                end
                2'h2, 2'h3: begin
                    d_next_status = D_FENCE;
                end
                default: ;
            endcase
        end
        D_JUDGE1: begin
            // 物理地址
            if (!d_satp[31] || d_privilege == 2'h3) begin
                // 命中缓存
                if (d_cache_hit0) begin
                    d_next_status = D_IDLE;
                    if (d_op[0]) begin
                        d_cache_tag_w_index(
                            d_vaddr[7:2],
                            d_cache_index0,
                            {1'h1, d_cache_tag_out[d_cache_index0][24:0]}
                        );
                        d_cache_w_index(
                            d_be,
                            d_cache_index0,
                            d_vaddr[7:0],
                            d_data
                        );
                        d_core_respond(
                            1'h0,
                            1'h0,
                            32'h0
                        );
                    end
                    else begin
                        d_core_respond(
                            1'h0,
                            1'h0,
                            d_cache_out[d_cache_index0]
                        );
                    end
                end
                // 未命中缓存，物理地址合法则填充缓存，否则响应
                else begin
                    // 填 d_cache
                    d_next_status = D_JUDGE2;
                    d_save_paddr = 1'h1;
                    nxt_d_paddr = {2'h0, d_vaddr};
                end
            end
            // D_TLB 命中
            else if (d_tlb_hit) begin
                // 权限正确
                if (d_tlb_pte) begin
                    // 需要先置 AD
                    if (!d_tlb_a() || (!d_tlb_d() && d_op[0])) begin
                        d_next_status = D_AD_READ;
                        d_save_pwc_or_tlb = 1'h1;
                        nxt_d_pwc_or_tlb = 1'h0;
                        nxt_d_set_d = !d_tlb_d() && d_op[0];
                        d_save_set_d = 1'h1;
                        d_save_pte_paddr = 1'h1;
                        nxt_d_pte_paddr = {d_tlb_tag_out[47:26], d_vaddr[19:10]};
                    end
                    // 命中缓存
                    else if (d_cache_hit1) begin
                        d_next_status = D_IDLE;
                        if (d_op[0]) begin
                            d_cache_tag_w_index(
                                d_vaddr[7:2],
                                d_cache_index1,
                                {1'h1, d_cache_tag_out[d_cache_index1][24:0]}
                            );
                            d_cache_w_index(
                                d_be,
                                d_cache_index1,
                                d_vaddr[7:0],
                                d_data
                            );
                            d_core_respond(
                                1'h0,
                                1'h0,
                                32'h0
                            );
                        end
                        else begin
                            d_core_respond(
                                1'h0,
                                1'h0,
                                d_cache_out[d_cache_index1]
                            );
                        end
                    end
                    // 未命中缓存，物理地址合法则填充缓存，否则响应
                    else begin
                        // 填 i_cache
                        d_next_status = D_JUDGE2;
                        d_save_paddr = 1'h1;
                        nxt_d_paddr = {d_tlb_out[31:10], d_vaddr[9:0]};
                    end
                end
                // 权限错误
                else begin
                    d_next_status = D_IDLE;
                    d_core_respond(
                        1'h0,
                        1'h1,
                        32'h0
                    );
                end
            end
            // PWC 命中
            else if (d_pwc_hit) begin
                // 是非叶，填充 d_tlb
                if (d_pwc_npte) begin
                    d_next_status = D_TLB_SEND;
                end
                // 是大页
                else if (d_pwc_pte) begin
                    // 需要先置 AD
                    if (!d_pwc_a() || (!d_pwc_d() && d_op[0])) begin
                        d_next_status = D_AD_READ;
                        d_save_pwc_or_tlb = 1'h1;
                        nxt_d_pwc_or_tlb = 1'h1;
                        nxt_d_set_d = !d_pwc_d() && d_op[0];
                        d_save_set_d = 1'h1;
                        d_save_pte_paddr = 1'h1;
                        nxt_d_pte_paddr = {d_satp[21:0], d_vaddr[29:20]};
                    end
                    // 命中缓存
                    else if (d_cache_hit2) begin
                        d_next_status = D_IDLE;
                        if (d_op[0]) begin
                            d_cache_tag_w_index(
                                d_vaddr[7:2],
                                d_cache_index2,
                                {1'h1, d_cache_tag_out[d_cache_index2][24:0]}
                            );
                            d_cache_w_index(
                                d_be,
                                d_cache_index2,
                                d_vaddr[7:0],
                                d_data
                            );
                            d_core_respond(
                                1'h0,
                                1'h0,
                                32'h0
                            );
                        end
                        else begin
                            d_core_respond(
                                1'h0,
                                1'h0,
                                d_cache_out[d_cache_index2]
                            );
                        end
                    end
                    // 未命中缓存，物理地址合法则填充缓存，否则响应
                    else begin
                        // 填 i_cache
                        d_next_status = D_JUDGE2;
                        d_save_paddr = 1'h1;
                        nxt_d_paddr = {d_pwc_out[31:20], d_vaddr[19:0]};
                    end
                end
                // 权限错误
                else begin
                    d_next_status = D_IDLE;
                    d_core_respond(
                        1'h0,
                        1'h1,
                        32'h0
                    );
                end
            end
            // 均未命中，填充 pwc
            else begin
                d_next_status = D_PWC_SEND;
            end
        end
        D_JUDGE2: begin
            case (pma(d_paddr))
                2'h0: begin
                    d_next_status = D_IDLE;
                    d_core_respond(
                        1'h1,
                        1'h0,
                        32'h0
                    );
                end
                2'h1: begin
                    if (d_op[0]) begin
                        d_core_respond(
                            1'h0,
                            1'h0,
                            32'h0
                        );
                    end
                    if (d_cache_need_wb()) begin
                        d_next_status = D_CACHE_WB;
                    end
                    else begin
                        d_next_status = D_CACHE_SEND;
                    end
                end
                2'h2, 2'h3: begin
                    d_next_status = D_RWT_SEND;
                    if (d_op[0]) begin
                        d_core_respond(
                            1'h0,
                            1'h0,
                            32'h0
                        );
                    end
                end
                default: ;
            endcase
        end
        D_PWC_SEND: begin
            if (!d_ram_request_busy) begin
                d_next_status = D_PWC_GET;
                d_ram_request(
                    1'h0,
                    16'h0,
                    {d_satp[21:0], d_vaddr[29:22], 3'h0},
                    128'h0
                );
            end
            else begin
                d_next_status = D_PWC_SEND;
            end
        end
        D_PWC_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_PWC_FILL;
                d_t_begin = 1'h1;
                d_pwc_w(
                    d_t[0] ? 4'h3 : 4'hc,
                    ~d_t[2:1],
                    {2{d_ram_respond_data}}
                );
                d_pwc_tag_w(
                    {d_vaddr[29:22], d_satp[30:22], 1'h1}
                );
            end
            else begin
                d_next_status = D_PWC_GET;
            end
        end
        D_PWC_FILL: begin
            d_pwc_w(
                d_t[0] ? 4'h3 : 4'hc,
                ~d_t[2:1],
                {2{d_ram_respond_data}}
            );
            if (d_t == 3'h0) begin
                d_next_status = D_UPDATE;
            end
            else begin
                d_next_status = D_PWC_FILL;
            end
        end
        D_TLB_SEND: begin
            if (!d_ram_request_busy) begin
                d_next_status = D_TLB_GET;
                d_ram_request(
                    1'h0,
                    16'h0,
                    {d_pwc_out[31:10], d_vaddr[19:12], 3'h0},
                    128'h0
                );
            end
            else begin
                d_next_status = D_TLB_SEND;
            end
        end
        D_TLB_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_TLB_FILL;
                d_t_begin = 1'h1;
                d_tlb_w(
                    d_t[0] ? 4'h3 : 4'hc,
                    {d_vaddr[14:12], ~d_t[2:1]},
                    {2{d_ram_respond_data}}
                );
                d_tlb_tag_w(
                    d_vaddr[14:12],
                    {d_pwc_out[31:10], d_vaddr[29:15], d_satp[30:22], d_pwc_out[5], 1'h1}
                );
            end
            else begin
                d_next_status = D_TLB_GET;
            end
        end
        D_TLB_FILL: begin
            d_tlb_w(
                d_t[0] ? 4'h3 : 4'hc,
                {d_vaddr[14:12], ~d_t[2:1]},
                {2{d_ram_respond_data}}
            );
            if (d_t == 3'h0) begin
                d_next_status = D_UPDATE;
            end
            else begin
                d_next_status = D_TLB_FILL;
            end
        end
        D_AD_READ: begin
            d_next_status = D_AD_SEND;
            d_read(d_pte_paddr);
            d_ad_save = 1'h1;
        end
        D_AD_SEND: begin
            if (!d_ram_request_busy) begin
                d_next_status = D_AD_GET;
                if (d_pwc_or_tlb) begin
                    d_pwc_w(
                        4'hf,
                        d_vaddr[21:20],
                        replace_ad(1'h1, d_set_d, saved_d_pwc_out)
                    );
                end
                else begin
                    d_tlb_w(
                        4'hf,
                        d_vaddr[14:10],
                        replace_ad(1'h1, d_set_d, saved_d_tlb_out)
                    );
                end
                if (d_cache_hit3) begin
                    d_cache_w_index(
                        4'hf,
                        d_cache_index3,
                        d_pte_paddr[7:0],
                        replace_ad(1'h1, d_set_d, d_cache_out[d_cache_index3])
                    );
                end
                d_ram_request(
                    1'h0,
                    16'h0,
                    {d_pte_paddr, 1'h0},
                    128'h0
                );
            end
            else begin
                d_next_status = D_AD_SEND;
            end
        end
        D_AD_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_AD_FILL;
                d_t1_begin = 1'h1;
                d_save_low_word = 1'h1;
                nxt_d_low_word = d_ram_respond_data;
            end
            else begin
                d_next_status = D_AD_GET;
            end
        end
        D_AD_FILL: begin
            if (d_t1 == 1'h0) begin
                d_next_status = D_AD_FILL;
                d_save_high_word = 1'h1;
                nxt_d_high_word = d_ram_respond_data;
            end
            else if (!d_ram_request_busy) begin
                d_ram_request(
                    1'h1,
                    16'hf << {d_pte_paddr[1:0], 2'h0},
                    {d_pte_paddr[31:2], 3'h0},
                    {4{replace_ad(1'h1, d_set_d, {d_high_word, d_low_word})}}
                );
                d_next_status = D_UPDATE;
            end
            else begin
                d_next_status = D_AD_FILL;
            end
        end
        D_UPDATE: begin
            d_next_status = D_JUDGE1;
            d_read({2'h0, d_vaddr});
        end
        D_CACHE_WB: begin
            if (!d_ram_request_busy) begin
                d_next_status = D_CACHE_SEND;
                d_ram_request(
                    1'h1,
                    16'hffff,
                    {d_cache_tag_out[d_ptr][24:1], d_paddr[7:2], 3'h0},
                    d_cache_line_out[d_ptr]
                );
            end
            else begin
                d_next_status = D_CACHE_WB;
            end
        end
        D_CACHE_SEND: begin
            if (!d_ram_request_busy) begin
                d_next_status = D_CACHE_GET;
                d_ram_request(
                    1'h0,
                    16'h0,
                    {d_paddr, 1'h0},
                    128'h0
                );
            end
            else begin
                d_next_status = D_CACHE_SEND;
            end
        end
        D_CACHE_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_CACHE_FILL;
                d_t_begin = 1'h1;
                d_save_low_word = 1'h1;
                if (d_op[0]) begin
                    nxt_d_low_word = {d_be[1] ? d_data[15:8] : d_ram_respond_data[15:8], d_be[0] ? d_data[7:0] : d_ram_respond_data[7:0]};
                    d_cache_w(
                        d_t[0] ? 4'h3 : 4'hc,
                        {d_vaddr[7:2], d_vaddr[1:0] + ~d_t[2:1]},
                        {2{d_be[1] ? d_data[15:8] : d_ram_respond_data[15:8], d_be[0] ? d_data[7:0] : d_ram_respond_data[7:0]}}
                    );
                end
                else begin
                    nxt_d_low_word = d_ram_respond_data;
                    d_cache_w(
                        d_t[0] ? 4'h3 : 4'hc,
                        {d_vaddr[7:2], d_vaddr[1:0] + ~d_t[2:1]},
                        {2{d_ram_respond_data}}
                    );
                end
                d_cache_tag_w(
                    d_paddr[7:2],
                    {d_op[0], d_paddr[31:8], 1'h1}
                );
            end
            else begin
                d_next_status = D_CACHE_GET;
            end
        end
        D_CACHE_FILL: begin
            if (d_t == 3'h6) begin
                d_save_high_word = 1'h1;
                if (d_op[0]) begin
                    nxt_d_high_word = {d_be[3] ? d_data[31:24] : d_ram_respond_data[15:8], d_be[2] ? d_data[23:16] : d_ram_respond_data[7:0]};
                    d_cache_w(
                        d_t[0] ? 4'h3 : 4'hc,
                        {d_vaddr[7:2], d_vaddr[1:0] + ~d_t[2:1]},
                        {2{d_be[3] ? d_data[31:24] : d_ram_respond_data[15:8], d_be[2] ? d_data[23:16] : d_ram_respond_data[7:0]}}
                    );
                end
                else begin
                    nxt_d_high_word = d_ram_respond_data;
                    d_cache_w(
                        d_t[0] ? 4'h3 : 4'hc,
                        {d_vaddr[7:2], d_vaddr[1:0] + ~d_t[2:1]},
                        {2{d_ram_respond_data}}
                    );
                end
            end
            else begin
                d_cache_w(
                    d_t[0] ? 4'h3 : 4'hc,
                    {d_vaddr[7:2], d_vaddr[1:0] + ~d_t[2:1]},
                    {2{d_ram_respond_data}}
                );
            end
            if (d_t == 3'h5 && !d_op[0]) begin
                d_core_respond(
                    1'h0,
                    1'h0,
                    {d_high_word, d_low_word}
                );
            end
            if (d_t == 3'h0) begin
                d_next_status = D_IDLE;
                d_add = 1'h1;
            end
            else begin
                d_next_status = D_CACHE_FILL;
            end
        end
        D_RWT_SEND: begin
            if (!d_ram_request_busy) begin
                if (d_op[0]) begin
                    d_next_status = D_IDLE;
                    d_ram_request(
                        1'h1,
                        {12'h0, d_be} << {d_paddr[1:0], 2'h0},
                        {d_paddr[31:2], 3'h0},
                        {4{d_data}}
                    );
                end
                else begin
                    d_next_status = D_RWT_GET;
                    d_ram_request(
                        1'h0,
                        16'h0,
                        {d_paddr, 1'h0},
                        128'h0
                    );
                end
            end
            else begin
                d_next_status = D_RWT_SEND;
            end
        end
        D_RWT_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_RWT_FILL;
                d_t1_begin = 1'h1;
                d_save_low_word = 1'h1;
                nxt_d_low_word = d_ram_respond_data;
            end
            else begin
                d_next_status = D_RWT_GET;
            end
        end
        D_RWT_FILL: begin
            if (d_t1 == 1'h0) begin
                d_next_status = D_RWT_FILL;
                d_save_high_word = 1'h1;
                nxt_d_high_word = d_ram_respond_data;
            end
            else begin
                d_next_status = D_IDLE;
                d_core_respond(
                    1'h0,
                    1'h0,
                    {d_high_word, d_low_word}
                );
            end
        end
        D_AD_I_READ: begin
            d_next_status = D_AD_I_SEND;
            d_read(i_pte_paddr);
        end
        D_AD_I_SEND: begin
            if (!d_ram_request_busy) begin
                if (d_cache_hit3) begin
                    d_cache_w_index(
                        4'hf,
                        d_cache_index3,
                        i_pte_paddr[7:0],
                        replace_ad(1'h1, 1'h0, d_cache_out[d_cache_index3])
                    );
                end
                d_next_status = D_AD_I_GET;
                d_ram_request(
                    1'h0,
                    16'h0,
                    {i_pte_paddr, 1'h0},
                    128'h0
                );
            end
            else begin
                d_next_status = D_AD_I_SEND;
            end
        end
        D_AD_I_GET: begin
            if (d_ram_respond_valid) begin
                d_next_status = D_AD_I_FILL;
                d_t1_begin = 1'h1;
                d_save_low_word = 1'h1;
                nxt_d_low_word = d_ram_respond_data;
            end
            else begin
                d_next_status = D_AD_I_GET;
            end
        end
        D_AD_I_FILL: begin
            if (d_t1 == 1'h0) begin
                d_next_status = D_AD_I_FILL;
                d_save_high_word = 1'h1;
                nxt_d_high_word = d_ram_respond_data;
            end
            else if (!d_ram_request_busy) begin
                d_ram_request(
                    1'h1,
                    16'hf << {i_pte_paddr[1:0], 2'h0},
                    {i_pte_paddr[31:2], 3'h0},
                    {4{replace_ad(1'h1, 1'h0, {d_high_word, d_low_word})}}
                );
                d_finish_i = 1'h1;
                case (d_ireturn)
                    1'h0:    d_next_status = D_IDLE;
                    1'h1:    d_next_status = D_FENCE;
                    default: ;
                endcase
            end
            else begin
                d_next_status = D_AD_I_FILL;
            end
        end
        D_FENCE: begin
            if (i2_status == I2_MODIFY_A2) begin
                d_next_status = D_AD_I_READ;
                d_save_ireturn = 1'h1;
                nxt_d_ireturn = 1'h1;
            end
            else if (i2_status == I2_FREE) begin
                f_begin = 1'h1;
                d_next_status = D_F_SCAN;
            end
            else begin
                d_next_status = D_FENCE;
            end
        end
        D_F_SCAN: begin
            d_read({24'h0, f_t[7:2], 2'h0});
            d_next_status = D_F_WORK;
        end
        D_F_WORK: begin
            if (!d_cache_tag_out[f_t[1:0]][0] || !d_cache_tag_out[f_t[1:0]][25]) begin
                f_add = 1'h1;
            end
            else if (!d_ram_request_busy) begin
                f_add = 1'h1;
                d_ram_request(1'h1, 16'hffff, {d_cache_tag_out[f_t[1:0]][24:1], f_t[7:2], 3'h0}, d_cache_line_out[f_t[1:0]]);
            end
            if (f_t[1:0] == 2'h3 && f_add) begin
                if (f_t[7:2] == 6'h3f) begin
                    d_next_status = D_F_DONE;
                end
                else begin
                    d_next_status = D_F_SCAN;
                end
            end
            else begin
                d_next_status = D_F_WORK;
            end
        end
        D_F_DONE: begin
            d_next_status = D_IDLE;
            if (d_op == 2'h2) begin
                i_pwc_tlb_flush = 1'h1;
                d_pwc_tlb_flush = 1'h1;      // sfence.vma:清 I/D PWC/TLB
            end
            else begin
                i_cache_flush = 1'h1;      // fence.i:清 I cache
            end
            d_core_respond(1'h0, 1'h0, 32'h0);
            d_finish_i = 1'h1;
        end
        default: ;
    endcase
    case (i2_status)
        I2_JUDGE1: begin
            if (d_status == D_FENCE) begin
                i2_next_status = I2_FREE;
            end
            else if (i_valid) begin
                // 物理地址
                if (!i_satp[31] || i_privilege == 2'h3) begin
                    // 命中缓存
                    if (i_cache_hit0) begin
                        i2_next_status = I2_JUDGE1;
                        i_read_lock = 1'h0;
                        i2_pop = 1'h1;
                        i_core_respond(
                            1'h0,
                            1'h0,
                            i_cache_out[i_cache_index0]
                        );
                    end
                    // 未命中缓存，物理地址合法则填充缓存，否则响应
                    else begin
                        i2_next_status = I2_JUDGE2;
                        i_save_paddr = 1'h1;
                        nxt_i_paddr = {2'h0, i_vaddr};
                    end
                end
                // I_TLB 命中
                else if (i_tlb_hit) begin
                    // 权限正确
                    if (i_tlb_pte) begin
                        // 需要先置 A
                        if (!i_tlb_a()) begin
                            i2_next_status = I2_MODIFY_A1;
                            i_save_pwc_or_tlb = 1'h1;
                            nxt_i_pwc_or_tlb = 1'h0;
                            i_save_pte_paddr = 1'h1;
                            nxt_i_pte_paddr = {i_tlb_tag_out[47:26], i_vaddr[19:10]};
                        end
                        // 命中缓存
                        else if (i_cache_hit1) begin
                            i2_next_status = I2_JUDGE1;
                            i_read_lock = 1'h0;
                            i2_pop = 1'h1;
                            i_core_respond(
                                1'h0,
                                1'h0,
                                i_cache_out[i_cache_index1]
                            );
                        end
                        // 未命中缓存，物理地址合法则填充缓存，否则响应
                        else begin
                            // 填 i_cache
                            i2_next_status = I2_JUDGE2;
                            i_save_paddr = 1'h1;
                            nxt_i_paddr = {i_tlb_out[31:10], i_vaddr[9:0]};
                        end
                    end
                    // 权限错误
                    else begin
                        i2_next_status = I2_JUDGE1;
                        i2_pop = 1'h1;
                        i_core_respond(
                            1'h0,
                            1'h1,
                            32'h0
                        );
                    end
                end
                // 判断 PWC 是否命中
                else if (i_pwc_hit) begin
                    // 是非叶，填充 i_tlb
                    if (i_pwc_npte) begin
                        // 要补充
                        i2_next_status = I2_TLB_SEND;
                    end
                    // 是大页
                    else if (i_pwc_pte) begin
                        // 需要先置 A
                        if (!i_pwc_a()) begin
                            i2_next_status = I2_MODIFY_A1;
                            i_save_pwc_or_tlb = 1'h1;
                            nxt_i_pwc_or_tlb = 1'h1;
                            i_save_pte_paddr = 1'h1;
                            nxt_i_pte_paddr = {i_satp[21:0], i_vaddr[29:20]};
                        end
                        // 命中缓存
                        else if (i_cache_hit2) begin
                            i2_next_status = I2_JUDGE1;
                            i2_pop = 1'h1;
                            i_core_respond(
                                1'h0,
                                1'h0,
                                i_cache_out[i_cache_index2]
                            );
                        end
                        // 未命中缓存，物理地址合法则填充缓存，否则响应
                        else begin
                            // 填 i_cache
                            i2_next_status = I2_JUDGE2;
                            i_save_paddr = 1'h1;
                            nxt_i_paddr = {i_pwc_out[31:20], i_vaddr[19:0]};
                        end
                    end
                    // 权限错误
                    else begin
                        i2_next_status = I2_JUDGE1;
                        i2_pop = 1'h1;
                        i_core_respond(
                            1'h0,
                            1'h1,
                            32'h0
                        );
                    end
                end
                // 均未命中，填充 pwc
                else begin
                    // 要补充
                    i2_next_status = I2_PWC_SEND;
                end
            end
            else begin
                i_read_lock = 1'h0;
                i2_next_status = I2_JUDGE1;
            end
        end
        I2_JUDGE2: begin
            // 根据 pma 判断
            if (pma(i_paddr) == 2'h0 || pma(i_paddr) == 2'h2) begin
                i2_next_status = I2_JUDGE1;
                i2_pop = 1'h1;
                i_core_respond(
                    1'h1,
                    1'h0,
                    32'h0
                );
            end
            else begin
                i2_next_status = I2_CACHE_SEND;
            end
        end
        I2_PWC_SEND: begin
            if (!i_ram_request_busy) begin
                i2_next_status = I2_PWC_GET;
                i_ram_request(
                    {i_satp[21:0], i_vaddr[29:22], 3'h0}
                );
            end
            else begin
                i2_next_status = I2_PWC_SEND;
            end
        end
        I2_PWC_GET: begin
            if (i_ram_respond_valid) begin
                i2_next_status = I2_PWC_FILL;
                i_t_begin = 1'h1;
                i_pwc_w(
                    i_t[0] ? 4'h3 : 4'hc,
                    ~i_t[2:1],
                    {2{i_ram_respond_data}}
                );
                i_pwc_tag_w(
                    {i_vaddr[29:22], i_satp[30:22], 1'h1}
                );
            end
            else begin
                i2_next_status = I2_PWC_GET;
            end
        end
        I2_PWC_FILL: begin
            i_pwc_w(
                i_t[0] ? 4'h3 : 4'hc,
                ~i_t[2:1],
                {2{i_ram_respond_data}}
            );
            if (i_t == 3'h0) begin
                i2_next_status = I2_UPDATE;
            end
            else begin
                i2_next_status = I2_PWC_FILL;
            end
        end
        I2_TLB_SEND: begin
            // 判断 TLB 所在物理地址是否命中缓存，否则直接请求内存
            if (!i_ram_request_busy) begin
                i2_next_status = I2_TLB_GET;
                i_ram_request(
                    {i_pwc_out[31:10], i_vaddr[19:12], 3'h0}
                );
            end
            else begin
                i2_next_status = I2_TLB_SEND;
            end
        end
        I2_TLB_GET: begin
            if (i_ram_respond_valid) begin
                i2_next_status = I2_TLB_FILL;
                i_t_begin = 1'h1;
                i_tlb_w(
                    i_t[0] ? 4'h3 : 4'hc,
                    {i_vaddr[14:12], ~i_t[2:1]},
                    {2{i_ram_respond_data}}
                );
                i_tlb_tag_w(
                    i_vaddr[14:12],
                    {i_pwc_out[31:10], i_vaddr[29:15], i_satp[30:22], i_pwc_out[5], 1'h1}
                );
            end
            else begin
                i2_next_status = I2_TLB_GET;
            end
        end
        I2_TLB_FILL: begin
            i_tlb_w(
                i_t[0] ? 4'h3 : 4'hc,
                {i_vaddr[14:12], ~i_t[2:1]},
                {2{i_ram_respond_data}}
            );
            if (i_t == 3'h0) begin
                i2_next_status = I2_UPDATE;
            end
            else begin
                i2_next_status = I2_TLB_FILL;
            end
        end
        I2_MODIFY_A1: begin
            i2_next_status = I2_MODIFY_A2;
            if (i_pwc_or_tlb) begin
                i_pwc_w(
                    4'hf,
                    i_vaddr[21:20],
                    replace_ad(1'h1, 1'h0, i_pwc_out)
                );
            end
            else begin
                i_tlb_w(
                    4'hf,
                    i_vaddr[14:10],
                    replace_ad(1'h1, 1'h0, i_tlb_out)
                );
            end
        end
        I2_MODIFY_A2: begin
            if (d_finish_i) begin
                i2_next_status = I2_UPDATE;
            end
            else begin
                i2_next_status = I2_MODIFY_A2;
            end
        end
        I2_UPDATE: begin
            i2_next_status = I2_JUDGE1;
            i_read(1'h1, i_vaddr);
        end
        I2_CACHE_SEND: begin
            if (!i_ram_request_busy) begin
                i2_next_status = I2_CACHE_GET;
                i_ram_request(
                    {i_paddr, 1'h0}
                );
            end
            else begin
                i2_next_status = I2_CACHE_SEND;
            end
        end
        I2_CACHE_GET: begin
            if (i_ram_respond_valid) begin
                i2_next_status = I2_CACHE_FILL;
                i_t_begin = 1'h1;
                i_save_low_word = 1'h1;
                i_cache_tag_w(
                    i_paddr[7:2],
                    {i_paddr[31:8], 1'h1}
                );
                i_cache_w(
                    i_t[0] ? 4'h3 : 4'hc,
                    {i_vaddr[7:2], i_vaddr[1:0] + ~i_t[2:1]},
                    {2{i_ram_respond_data}}
                );
            end
            else begin
                i2_next_status = I2_CACHE_GET;
            end
        end
        I2_CACHE_FILL: begin
            i_cache_w(
                i_t[0] ? 4'h3 : 4'hc,
                {i_vaddr[7:2], i_vaddr[1:0] + ~i_t[2:1]},
                {2{i_ram_respond_data}}
            );
            if (i_t == 3'h6) begin
                i_save_high_word = 1'h1;
            end
            if (i_t == 3'h5) begin
                i_core_respond(
                    1'h0,
                    1'h0,
                    {i_high_word, i_low_word}
                );
            end
            if (i_t == 3'h0) begin
                i2_next_status = I2_JUDGE1;
                i_add = 1'h1;
                i2_pop = 1'h1;
            end
            else begin
                i2_next_status = I2_CACHE_FILL;
            end
        end
        I2_FREE: begin
            if (d_finish_i) begin
                i2_next_status = I2_UPDATE;   // fence 后队头快照全部作废，重采样
            end
            else begin
                i2_next_status = I2_FREE;
            end
        end
        default: ;
    endcase
    case (i1_status)
        I1_IDLE: begin
            i_core_request_busy = 1'h0;
            if (i_core_request_valid) begin
                i1_push = 1'h1;
                i1_next_status = I1_LOOKUP;
            end
            else begin
                i1_next_status = I1_IDLE;
            end
        end
        I1_LOOKUP: begin
            if (!i_read_lock) begin
                i_core_request_busy = 1'h0;
                i_read(1'h0, saved_i_core_request_vaddr);
                i2_push = 1'h1;
                if (i_core_request_valid) begin
                    i1_next_status = I1_LOOKUP;
                    i1_push = 1'h1;
                end
                else begin
                    i1_next_status = I1_IDLE;
                end
            end
            else begin
                i_core_request_busy = 1'h1;
                i1_next_status = I1_LOOKUP;
            end
        end
        default: ;
    endcase
end

endmodule
