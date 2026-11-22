`timescale 1ns / 1ns

module d_translate (
    input              clk,
    input              rst_n,

    input              valid,

    input              flush,
    input              f_by_va,
    input      [19:0]  f_va,

    input              tlb_we,
    input      [3:0]   tlb_waddr,
    input      [31:0]  tlb_in,
    input      [26:0]  tlb_tag_in,

    input              pwc_we,
    input      [1:0]   pwc_waddr,
    input      [31:0]  pwc_in,
    input      [17:0]  pwc_tag_in,

    input              MPRV,
    input              MXR,
    input              SUM,
    input      [1:0]   MPP,
    input      [1:0]   privilege,
    input      [31:0]  satp,

    input              op,
    input      [29:0]  vaddr,
    output reg         tlb_pwc_fill,
    output reg         fill_src, // 0: tlb 1: pwc
    output reg         p_fault,
    output reg [1:0]   _privilege,
    output reg [31:0]  paddr
);

reg [15:0] tlb_last_index;
reg [3:0]  pwc_last_index;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlb_last_index <= 16'h0;
        pwc_last_index <= 4'h0;
    end
    else begin
        if (tlb_we) begin
            if (!tlb_valid0[tlb_waddr]) begin
                tlb_last_index[tlb_waddr] <= 1'h0;
            end
            else if (!tlb_valid1[tlb_waddr]) begin
                tlb_last_index[tlb_waddr] <= 1'h1;
            end
            else if (tlb_last_index[tlb_waddr]) begin
                tlb_last_index[tlb_waddr] <= 1'h0;
            end
            else begin
                tlb_last_index[tlb_waddr] <= 1'h1;
            end
        end
        else if (valid && s2_tlb_used) begin
            tlb_last_index[s2_tlb_addr] <= s2_tlb_index;
        end
        if (pwc_we) begin
            if (!pwc_valid0[pwc_waddr]) begin
                pwc_last_index[pwc_waddr] <= 1'h0;
            end
            else if (!pwc_valid1[pwc_waddr]) begin
                pwc_last_index[pwc_waddr] <= 1'h1;
            end
            else if (pwc_last_index[pwc_waddr]) begin
                pwc_last_index[pwc_waddr] <= 1'h0;
            end
            else begin
                pwc_last_index[pwc_waddr] <= 1'h1;
            end
        end
        else if (valid && s2_pwc_used) begin
            pwc_last_index[s2_pwc_addr] <= s2_pwc_index;
        end
    end
end

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

wire [31:0] tlb_out0     = tlb0[vaddr[13:10]];
wire [31:0] tlb_out1     = tlb1[vaddr[13:10]];
wire [26:0] tlb_tag_out0 = {tlb_tag0[vaddr[13:10]], tlb_valid0[vaddr[13:10]]};
wire [26:0] tlb_tag_out1 = {tlb_tag1[vaddr[13:10]], tlb_valid1[vaddr[13:10]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlb_valid0 <= 16'h0;
        tlb_valid1 <= 16'h0;
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
            tlb_valid0[tlb_waddr] <= tlb_tag_in[0];
        end
        else if (!tlb_valid1[tlb_waddr]) begin
            tlb_valid1[tlb_waddr] <= tlb_tag_in[0];
        end
        else if (tlb_last_index[tlb_waddr]) begin
            tlb_valid0[tlb_waddr] <= tlb_tag_in[0];
        end
        else begin
            tlb_valid1[tlb_waddr] <= tlb_tag_in[0];
        end
    end
end

always @(posedge clk) begin
    if (tlb_we) begin
        if (!tlb_valid0[tlb_waddr]) begin
            tlb0[tlb_waddr] <= tlb_in;
            tlb_tag0[tlb_waddr] <= tlb_tag_in[26:1];
        end
        else if (!tlb_valid1[tlb_waddr]) begin
            tlb1[tlb_waddr] <= tlb_in;
            tlb_tag1[tlb_waddr] <= tlb_tag_in[26:1];
        end
        else if (tlb_last_index[tlb_waddr]) begin
            tlb0[tlb_waddr] <= tlb_in;
            tlb_tag0[tlb_waddr] <= tlb_tag_in[26:1];
        end
        else begin
            tlb1[tlb_waddr] <= tlb_in;
            tlb_tag1[tlb_waddr] <= tlb_tag_in[26:1];
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

wire [31:0] pwc_out0     = pwc0[vaddr[21:20]];
wire [31:0] pwc_out1     = pwc1[vaddr[21:20]];
wire [17:0] pwc_tag_out0 = {pwc_tag0[vaddr[21:20]], pwc_valid0[vaddr[21:20]]};
wire [17:0] pwc_tag_out1 = {pwc_tag1[vaddr[21:20]], pwc_valid1[vaddr[21:20]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwc_valid0 <= 4'h0;
        pwc_valid1 <= 4'h0;
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
            pwc_valid0[pwc_waddr] <= pwc_tag_in[0];
        end
        else if (!pwc_valid1[pwc_waddr]) begin
            pwc_valid1[pwc_waddr] <= pwc_tag_in[0];
        end
        else if (pwc_last_index[pwc_waddr]) begin
            pwc_valid0[pwc_waddr] <= pwc_tag_in[0];
        end
        else begin
            pwc_valid1[pwc_waddr] <= pwc_tag_in[0];
        end
    end
end

always @(posedge clk) begin
    if (pwc_we) begin
        if (!pwc_valid0[pwc_waddr]) begin
            pwc0[pwc_waddr] <= pwc_in;
            pwc_tag0[pwc_waddr] <= pwc_tag_in[17:1];
        end
        else if (!pwc_valid1[pwc_waddr]) begin
            pwc1[pwc_waddr] <= pwc_in;
            pwc_tag1[pwc_waddr] <= pwc_tag_in[17:1];
        end
        else if (pwc_last_index[pwc_waddr]) begin
            pwc0[pwc_waddr] <= pwc_in;
            pwc_tag0[pwc_waddr] <= pwc_tag_in[17:1];
        end
        else begin
            pwc1[pwc_waddr] <= pwc_in;
            pwc_tag1[pwc_waddr] <= pwc_tag_in[17:1];
        end
    end
end
// #endregion

// #region 组合逻辑
wire [1:0] eff_privilege = privilege == 2'h3 && MPRV ? MPP : privilege;

wire tlb_hit0 = tlb_tag_out0[0] &&
                tlb_tag_out0[26:11] == vaddr[29:14] &&
                (tlb_tag_out0[10:2] == satp[30:22] ||
                 tlb_tag_out0[1] ||
                 tlb_out0[5]);

wire tlb_hit1 = tlb_tag_out1[0] &&
                tlb_tag_out1[26:11] == vaddr[29:14] &&
                (tlb_tag_out1[10:2] == satp[30:22] ||
                 tlb_tag_out1[1] ||
                 tlb_out1[5]);

wire tlb_hit = tlb_hit0 || tlb_hit1;
wire tlb_index = tlb_hit1;

wire tlb_pte0 = tlb_out0[0] &&
                (tlb_out0[6] && (tlb_out0[7] || !op)) &&
                (tlb_out0[1] || !tlb_out0[2]) &&
                (op ? tlb_out0[2] : (MXR && tlb_out0[3]) || tlb_out0[1]) &&
                ((SUM && eff_privilege[0]) || tlb_out0[4] != eff_privilege[0]);

wire tlb_pte1 = tlb_out1[0] &&
                (tlb_out1[6] && (tlb_out1[7] || !op)) &&
                (tlb_out1[1] || !tlb_out1[2]) &&
                (op ? tlb_out1[2] : (MXR && tlb_out1[3]) || tlb_out1[1]) &&
                ((SUM && eff_privilege[0]) || tlb_out1[4] != eff_privilege[0]);

wire tlb_pte = tlb_index ? tlb_pte1 : tlb_pte0;

wire [31:0] tlb_paddr = tlb_index ? {tlb_out1[31:10], vaddr[9:0]} : {tlb_out0[31:10], vaddr[9:0]};



wire pwc_hit0 = pwc_tag_out0[0] &&
                pwc_tag_out0[17:10] == vaddr[29:22] &&
                (pwc_tag_out0[9:1] == satp[30:22] ||
                 pwc_out0[5]);

wire pwc_hit1 = pwc_tag_out1[0] &&
                pwc_tag_out1[17:10] == vaddr[29:22] &&
                (pwc_tag_out1[9:1] == satp[30:22] ||
                 pwc_out1[5]);

wire pwc_hit = pwc_hit0 || pwc_hit1;
wire pwc_index = pwc_hit1;

wire pwc_pte0 = pwc_out0[0] &&
                (pwc_out0[6] && (pwc_out0[7] || !op)) &&
                (pwc_out0[1] || !pwc_out0[2]) &&
                pwc_out0[19:10] == 10'h0 &&
                (op ? pwc_out0[2] : (MXR && pwc_out0[3]) || pwc_out0[1]) &&
                ((SUM && eff_privilege[0]) || pwc_out0[4] != eff_privilege[0]);

wire pwc_pte1 = pwc_out1[0] &&
                (pwc_out1[6] && (pwc_out1[7] || !op)) &&
                (pwc_out1[1] || !pwc_out1[2]) &&
                pwc_out1[19:10] == 10'h0 &&
                (op ? pwc_out1[2] : (MXR && pwc_out1[3]) || pwc_out1[1]) &&
                ((SUM && eff_privilege[0]) || pwc_out1[4] != eff_privilege[0]);

wire pwc_pte = pwc_index ? pwc_pte1 : pwc_pte0;

wire pwc_npte0 = pwc_out0[0] &&
                 !(pwc_out0[1] || pwc_out0[2] ||
                   pwc_out0[3] || pwc_out0[4] ||
                   pwc_out0[6] || pwc_out0[7]);

wire pwc_npte1 = pwc_out1[0] &&
                 !(pwc_out1[1] || pwc_out1[2] ||
                   pwc_out1[3] || pwc_out1[4] ||
                   pwc_out1[6] || pwc_out1[7]);

wire pwc_npte = pwc_index ? pwc_npte1 : pwc_npte0;

wire [31:0] pwc_paddr = pwc_index ? {pwc_out1[31:20], vaddr[19:0]} : {pwc_out0[31:20], vaddr[19:0]};

reg s1_tlb_used;
reg s1_tlb_index;
reg [3:0] s1_tlb_addr;
reg s1_pwc_used;
reg s1_pwc_index;
reg [1:0] s1_pwc_addr;
reg s2_tlb_used;
reg s2_tlb_index;
reg [3:0] s2_tlb_addr;
reg s2_pwc_used;
reg s2_pwc_index;
reg [1:0] s2_pwc_addr;

always @(posedge clk) begin
    p_fault   <= 1'h0;
    tlb_pwc_fill <= 1'h0;
    fill_src     <= 1'h0;
    _privilege   <= eff_privilege;
    s1_tlb_used  <= 1'h0;
    s1_tlb_index <= tlb_index;
    s1_tlb_addr  <= vaddr[13:10];
    s1_pwc_used  <= 1'h0;
    s1_pwc_index <= pwc_index;
    s1_pwc_addr  <= vaddr[21:20];
    s2_tlb_used  <= s1_tlb_used;
    s2_tlb_index <= s1_tlb_index;
    s2_tlb_addr  <= s1_tlb_addr;
    s2_pwc_used  <= s1_pwc_used;
    s2_pwc_index <= s1_pwc_index;
    s2_pwc_addr  <= s1_pwc_addr;
    if (!satp[31] || eff_privilege == 2'h3) begin
        // 物理地址，直接申请 d-cache
        paddr <= {2'h0, vaddr};
        // pma 检查
    end
    else if (tlb_hit) begin
        s1_tlb_used <= 1'h1;
        if (tlb_pte) begin
            // TLB 翻译，直接申请 d-cache
            paddr <= tlb_paddr;
            // pma 检查
        end
        else begin
            // 权限错误，直接响应
            paddr <= tlb_paddr;
            p_fault <= 1'h1;
        end
    end
    else if (pwc_hit) begin
        s1_pwc_used <= 1'h1;
        if (pwc_npte) begin
            // 填充 TLB，申请 d-cache
            tlb_pwc_fill <= 1'h1;
            fill_src <= 1'h0;
            paddr <= pwc_index ? {pwc_out1[31:10], vaddr[19:10]} : {pwc_out0[31:10], vaddr[19:10]};
            // pma 检查
        end
        else if (pwc_pte) begin
            // PWC 翻译，直接申请 d-cache
            paddr <= pwc_paddr;
            // pma 检查
        end
        else begin
            // 权限错误，直接响应
            paddr <= pwc_paddr;
            p_fault <= 1'h1;
        end
    end
    else begin
        // 填充 PWC，申请 d-cache
        tlb_pwc_fill <= 1'h1;
        fill_src <= 1'h1;
        paddr <= {satp[21:0], vaddr[29:20]};
        // pma 检查
    end
end
// #endregion

endmodule
