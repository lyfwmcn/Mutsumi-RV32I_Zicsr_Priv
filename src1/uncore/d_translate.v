`timescale 1ns / 1ns

/**
 * 接口说明：
 * privilege 必须考虑了 MPRV
 * flush/f_by_va/f_va: 冲刷 tlb/pwc，可选 vaddr 匹配
 * s0_fill_src: 0: tlb  1: pwc
 * 模块功能：
 * 处理 op = 0/1 两种情况，根据 vaddr 判断是否需要填充 tlb/pwc
 * 是否发生 page_fault，提供 paddr
 */
module d_translate (
    input              clk,
    input              rst_n,

    input              s2_tlb_used,
    input              s2_tlb_index,
    input      [3:0]   s2_tlb_addr,
    input              s2_pwc_used,
    input              s2_pwc_index,
    input      [1:0]   s2_pwc_addr,

    input              flush,
    input              f_by_va,
    input      [19:0]  f_va,

    input              tlb_we,
    input      [3:0]   tlb_waddr,
    input      [31:0]  tlb_in,
    input      [25:0]  tlb_tag_in,

    input              pwc_we,
    input      [1:0]   pwc_waddr,
    input      [31:0]  pwc_in,
    input      [16:0]  pwc_tag_in,

    input              MXR,
    input              SUM,
    input      [1:0]   privilege,
    input      [31:0]  satp,

    input              op,
    input      [29:0]  vaddr,
    output reg         s0_tlb_used,
    output reg         s0_tlb_index,
    output reg         s0_pwc_used,
    output reg         s0_pwc_index,
    output reg         s0_tp_fill,
    output reg         s0_fill_src,
    output reg         s0_pwc_g,
    output reg         s0_p_fault,
    output reg [31:0]  s0_paddr
);

// #region TLB, TLB-tag
(* ram_style = "distributed" *)
reg [31:0] tlb0    [15:0];
(* ram_style = "distributed" *)
reg [31:0] tlb1    [15:0];
(* ram_style = "distributed" *)
reg [25:0] tlb_tag0 [15:0];
(* ram_style = "distributed" *)
reg [25:0] tlb_tag1 [15:0];
(* ram_style = "registers" *)
reg [15:0] tlb_valid0;
(* ram_style = "registers" *)
reg [15:0] tlb_valid1;
(* ram_style = "registers" *)
reg [15:0] tlb_last_index;

wire [31:0] tlb_out0     = tlb0[vaddr[13:10]];
wire [31:0] tlb_out1     = tlb1[vaddr[13:10]];
wire [26:0] tlb_tag_out0 = {tlb_tag0[vaddr[13:10]], tlb_valid0[vaddr[13:10]]};
wire [26:0] tlb_tag_out1 = {tlb_tag1[vaddr[13:10]], tlb_valid1[vaddr[13:10]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlb_valid0 <= 16'h0;
        tlb_valid1 <= 16'h0;
        tlb_last_index <= 16'h0;
    end
    else if (flush) begin
        if (f_by_va) begin
            if (tlb_tag0[f_va[3:0]][25:10] == f_va[19:4]) begin
                tlb_valid0[f_va[3:0]] <= 1'h0;
            end
            if (tlb_tag1[f_va[3:0]][25:10] == f_va[19:4]) begin
                tlb_valid1[f_va[3:0]] <= 1'h0;
            end
        end
        else begin
            tlb_valid0 <= 16'h0;
            tlb_valid1 <= 16'h0;
        end
    end
    else if (tlb_we) begin
        if (!tlb_valid0[tlb_waddr]) begin
            tlb_valid0[tlb_waddr] <= 1'h1;
            tlb_last_index[tlb_waddr] <= 1'h0;
        end
        else if (!tlb_valid1[tlb_waddr]) begin
            tlb_valid1[tlb_waddr] <= 1'h1;
            tlb_last_index[tlb_waddr] <= 1'h1;
        end
        else if (tlb_last_index[tlb_waddr]) begin
            tlb_valid0[tlb_waddr] <= 1'h1;
            tlb_last_index[tlb_waddr] <= 1'h0;
        end
        else begin
            tlb_valid1[tlb_waddr] <= 1'h1;
            tlb_last_index[tlb_waddr] <= 1'h1;
        end
    end
    else if (s2_tlb_used) begin
        tlb_last_index[s2_tlb_addr] <= s2_tlb_index;
    end
end

always @(posedge clk) begin
    if (tlb_we) begin
        if (!tlb_valid0[tlb_waddr]) begin
            tlb0[tlb_waddr] <= tlb_in;
            tlb_tag0[tlb_waddr] <= tlb_tag_in;
        end
        else if (!tlb_valid1[tlb_waddr]) begin
            tlb1[tlb_waddr] <= tlb_in;
            tlb_tag1[tlb_waddr] <= tlb_tag_in;
        end
        else if (tlb_last_index[tlb_waddr]) begin
            tlb0[tlb_waddr] <= tlb_in;
            tlb_tag0[tlb_waddr] <= tlb_tag_in;
        end
        else begin
            tlb1[tlb_waddr] <= tlb_in;
            tlb_tag1[tlb_waddr] <= tlb_tag_in;
        end
    end
end
// #endregion

// #region PWC, PWC-tag
(* ram_style = "distributed" *)
reg [31:0] pwc0     [3:0];
(* ram_style = "distributed" *)
reg [31:0] pwc1     [3:0];
(* ram_style = "distributed" *)
reg [16:0] pwc_tag0 [3:0];
(* ram_style = "distributed" *)
reg [16:0] pwc_tag1 [3:0];
(* ram_style = "registers" *)
reg [3:0]  pwc_valid0;
(* ram_style = "registers" *)
reg [3:0]  pwc_valid1;
(* ram_style = "registers" *)
reg [3:0]  pwc_last_index;

wire [31:0] pwc_out0     = pwc0[vaddr[21:20]];
wire [31:0] pwc_out1     = pwc1[vaddr[21:20]];
wire [17:0] pwc_tag_out0 = {pwc_tag0[vaddr[21:20]], pwc_valid0[vaddr[21:20]]};
wire [17:0] pwc_tag_out1 = {pwc_tag1[vaddr[21:20]], pwc_valid1[vaddr[21:20]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwc_valid0 <= 4'h0;
        pwc_valid1 <= 4'h0;
        pwc_last_index <= 4'h0;
    end
    else if (flush) begin
        if (f_by_va) begin
            if (pwc_tag0[f_va[11:10]][16:9] == f_va[19:12]) begin
                pwc_valid0[f_va[11:10]] <= 1'h0;
            end
            if (pwc_tag1[f_va[11:10]][16:9] == f_va[19:12]) begin
                pwc_valid1[f_va[11:10]] <= 1'h0;
            end
        end
        else begin
            pwc_valid0 <= 4'h0;
            pwc_valid1 <= 4'h0;
        end
    end
    else if (pwc_we) begin
        if (!pwc_valid0[pwc_waddr]) begin
            pwc_valid0[pwc_waddr] <= 1'h1;
            pwc_last_index[pwc_waddr] <= 1'h0;
        end
        else if (!pwc_valid1[pwc_waddr]) begin
            pwc_valid1[pwc_waddr] <= 1'h1;
            pwc_last_index[pwc_waddr] <= 1'h1;
        end
        else if (pwc_last_index[pwc_waddr]) begin
            pwc_valid0[pwc_waddr] <= 1'h1;
            pwc_last_index[pwc_waddr] <= 1'h0;
        end
        else begin
            pwc_valid1[pwc_waddr] <= 1'h1;
            pwc_last_index[pwc_waddr] <= 1'h1;
        end
    end
    else if (s2_pwc_used) begin
        pwc_last_index[s2_pwc_addr] <= s2_pwc_index;
    end
end

always @(posedge clk) begin
    if (pwc_we) begin
        if (!pwc_valid0[pwc_waddr]) begin
            pwc0[pwc_waddr] <= pwc_in;
            pwc_tag0[pwc_waddr] <= pwc_tag_in;
        end
        else if (!pwc_valid1[pwc_waddr]) begin
            pwc1[pwc_waddr] <= pwc_in;
            pwc_tag1[pwc_waddr] <= pwc_tag_in;
        end
        else if (pwc_last_index[pwc_waddr]) begin
            pwc0[pwc_waddr] <= pwc_in;
            pwc_tag0[pwc_waddr] <= pwc_tag_in;
        end
        else begin
            pwc1[pwc_waddr] <= pwc_in;
            pwc_tag1[pwc_waddr] <= pwc_tag_in;
        end
    end
end
// #endregion

// #region 组合逻辑
function automatic tlb_hit_judge;
    input [26:0] tlb_tag_out;
    input [31:0] tlb_out;
    begin
        tlb_hit_judge = tlb_tag_out[0] &&
                        tlb_tag_out[26:11] == vaddr[29:14] &&
                        (tlb_tag_out[10:2] == satp[30:22] ||
                        tlb_tag_out[1] ||
                        tlb_out[5]);
    end
endfunction
wire tlb_hit0  = tlb_hit_judge(tlb_tag_out0, tlb_out0);
wire tlb_hit1  = tlb_hit_judge(tlb_tag_out1, tlb_out1);
wire tlb_hit   = tlb_hit0 || tlb_hit1;
wire tlb_index = tlb_hit1;

function automatic tlb_pte_judge;
    input [31:0] tlb_out;
    begin
        tlb_pte_judge = tlb_out[0] &&
                        (tlb_out[6] && (tlb_out[7] || !op)) &&
                        (tlb_out[1] || !tlb_out[2]) &&
                        (op ? tlb_out[2] : (MXR && tlb_out[3]) || tlb_out[1]) &&
                        ((SUM && privilege[0]) || tlb_out[4] != privilege[0]);
    end
endfunction
wire tlb_pte0 = tlb_pte_judge(tlb_out0);
wire tlb_pte1 = tlb_pte_judge(tlb_out1);
wire tlb_pte  = tlb_index ? tlb_pte1 : tlb_pte0;

wire [31:0] tlb_out = tlb_index ? tlb_out1 : tlb_out0;

function automatic pwc_hit_judge;
    input [17:0] pwc_tag_out;
    input [31:0] pwc_out;
    begin
        pwc_hit_judge = pwc_tag_out[0] &&
                        pwc_tag_out[17:10] == vaddr[29:22] &&
                        (pwc_tag_out[9:1] == satp[30:22] ||
                        pwc_out[5]);
    end
endfunction
wire pwc_hit0  = pwc_hit_judge(pwc_tag_out0, pwc_out0);
wire pwc_hit1  = pwc_hit_judge(pwc_tag_out1, pwc_out1);
wire pwc_hit   = pwc_hit0 || pwc_hit1;
wire pwc_index = pwc_hit1;

function automatic pwc_pte_judge;
    input [31:0] pwc_out;
    begin
        pwc_pte_judge = pwc_out[0] &&
                        (pwc_out[6] && (pwc_out[7] || !op)) &&
                        (pwc_out[1] || !pwc_out[2]) &&
                        pwc_out[19:10] == 10'h0 &&
                        (op ? pwc_out[2] : (MXR && pwc_out[3]) || pwc_out[1]) &&
                        ((SUM && privilege[0]) || pwc_out[4] != privilege[0]);
    end
endfunction
wire pwc_pte0 = pwc_pte_judge(pwc_out0);
wire pwc_pte1 = pwc_pte_judge(pwc_out1);
wire pwc_pte  = pwc_index ? pwc_pte1 : pwc_pte0;

function automatic pwc_npte_judge;
    input [31:0] pwc_out;
    begin
        pwc_npte_judge = pwc_out[0] &&
                         !(pwc_out[1] || pwc_out[2] ||
                           pwc_out[3] || pwc_out[4] ||
                           pwc_out[6] || pwc_out[7]);
    end
endfunction
wire pwc_npte0 = pwc_npte_judge(pwc_out0);
wire pwc_npte1 = pwc_npte_judge(pwc_out1);
wire pwc_npte  = pwc_index ? pwc_npte1 : pwc_npte0;

wire [31:0] pwc_out = pwc_index ? pwc_out1 : pwc_out0;

always @(*) begin
    s0_tlb_used  = 1'h0;
    s0_tlb_index = tlb_index;
    s0_pwc_used  = 1'h0;
    s0_pwc_index = pwc_index;
    s0_tp_fill   = 1'h0;
    s0_fill_src  = 1'h0;
    s0_pwc_g     = pwc_out[5];
    s0_p_fault   = 1'h0;
    if (!satp[31] || privilege == 2'h3) begin
        s0_paddr = {2'h0, vaddr};
    end
    else if (tlb_hit) begin
        s0_tlb_used = 1'h1;
        s0_paddr = {tlb_out[31:10], vaddr[9:0]};
        if (!tlb_pte) begin
            s0_p_fault = 1'h1;
        end
    end
    else if (pwc_hit) begin
        s0_pwc_used = 1'h1;
        if (pwc_npte) begin
            // 填充 TLB，申请 d-cache
            s0_tp_fill = 1'h1;
            s0_fill_src = 1'h0;
            s0_paddr = {pwc_out[31:10], vaddr[19:10]};
        end
        else begin
            s0_paddr = {pwc_out[31:20], vaddr[19:0]};
            if (!pwc_pte) begin
                s0_p_fault = 1'h1;
            end
        end
    end
    else begin
        // 填充 PWC，申请 d-cache
        s0_tp_fill = 1'h1;
        s0_fill_src = 1'h1;
        s0_paddr = {satp[21:0], vaddr[29:20]};
    end
end
// #endregion

endmodule
