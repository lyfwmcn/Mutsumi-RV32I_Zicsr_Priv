`timescale 1ns / 1ns

module d_translate (
    input              clk,
    input              rst_n,

    input              flush,
    input              flush_vaddr_valid,
    input      [19:0]  flush_vaddr,

    input              tlb_we,
    input      [4:0]   tlb_waddr,
    input      [31:0]  tlb_in,
    input      [25:0]  tlb_tag_in,

    input              pwc_we,
    input      [2:0]   pwc_waddr,
    input      [31:0]  pwc_in,
    input      [16:0]  pwc_tag_in,

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
    output reg         page_fault,
    output reg [1:0]   _privilege,
    output reg [31:0]  paddr
);

// #region TLB, TLB-tag
(* ram_style = "distributed" *)
reg [31:0] tlb     [31:0];
(* ram_style = "distributed" *)
reg [24:0] tlb_tag [31:0];
(* ram_style = "registers" *)
reg [31:0] tlb_valid;

wire [31:0] tlb_out = tlb[vaddr[14:10]];
wire [25:0] tlb_tag_out = {tlb_tag[vaddr[14:10]], tlb_valid[vaddr[14:10]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlb_valid <= 32'h0;
    end
    else if (flush) begin
        if (flush_vaddr_valid) begin
            if (tlb_tag[flush_vaddr[4:0]][24:10] == flush_vaddr[19:5]) begin
                tlb_valid[flush_vaddr[4:0]] <= 1'h0;
            end
        end
        else begin
            tlb_valid <= 32'h0;
        end
    end
    else if (tlb_we) begin
        tlb_valid[tlb_waddr] <= tlb_tag_in[0];
    end
end

always @(posedge clk) begin
    if (tlb_we) begin
        tlb[tlb_waddr] <= tlb_in;
        tlb_tag[tlb_waddr] <= tlb_tag_in[25:1];
    end
end
// #endregion

// #region PWC, PWC-tag
(* ram_style = "distributed" *)
reg [31:0] pwc     [7:0];
(* ram_style = "distributed" *)
reg [15:0] pwc_tag [7:0];
(* ram_style = "registers" *)
reg [7:0]  pwc_valid;

wire [31:0] pwc_out = pwc[vaddr[22:20]];
wire [16:0] pwc_tag_out = {pwc_tag[vaddr[22:20]], pwc_valid[vaddr[22:20]]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwc_valid <= 8'h0;
    end
    else if (flush) begin
        if (flush_vaddr_valid) begin
            if (pwc_tag[flush_vaddr[12:10]][15:9] == flush_vaddr[19:13]) begin
                pwc_valid[flush_vaddr[12:10]] <= 1'h0;
            end
        end
        else begin
            pwc_valid <= 8'h0;
        end
    end
    else if (pwc_we) begin
        pwc_valid[pwc_waddr] <= pwc_tag_in[0];
    end
end

always @(posedge clk) begin
    if (pwc_we) begin
        pwc[pwc_waddr] <= pwc_in;
        pwc_tag[pwc_waddr] <= pwc_tag_in[16:1];
    end
end
// #endregion

// #region 组合逻辑
wire [1:0] eff_privilege = privilege == 2'h3 && MPRV ? MPP : privilege;

wire tlb_hit = tlb_tag_out[0] &&
               tlb_tag_out[25:11] == vaddr[29:15] &&
               (tlb_tag_out[10:2] == satp[30:22] ||
                tlb_tag_out[1] ||
                tlb_out[5]);

wire tlb_pte = tlb_out[0] &&
               (tlb_out[6] && (tlb_out[7] || !op)) &&
               (tlb_out[1] || !tlb_out[2]) &&
               (op ? tlb_out[2] : (MXR && tlb_out[3]) || tlb_out[1]) &&
               ((SUM && eff_privilege[0]) || tlb_out[4] != eff_privilege[0]);

wire pwc_hit = pwc_tag_out[0] &&
               pwc_tag_out[16:10] == vaddr[29:23] &&
               (pwc_tag_out[9:1] == satp[30:22] ||
                pwc_out[5]);

wire pwc_pte = pwc_out[0] &&
               (pwc_out[6] && (pwc_out[7] || !op)) &&
               (pwc_out[1] || !pwc_out[2]) &&
               pwc_out[19:10] == 10'h0 &&
               (op ? pwc_out[2] : (MXR && pwc_out[3]) || pwc_out[1]) &&
               ((SUM && eff_privilege[0]) || pwc_out[4] != eff_privilege[0]);

wire pwc_npte = pwc_out[0] &&
                !(pwc_out[1] || pwc_out[2] ||
                  pwc_out[3] || pwc_out[4] ||
                  pwc_out[6] || pwc_out[7]);

always @(posedge clk) begin
    page_fault   <= 1'h0;
    tlb_pwc_fill <= 1'h0;
    fill_src     <= 1'h0;
    _privilege   <= eff_privilege;
    if (!satp[31] || eff_privilege == 2'h3) begin
        // 物理地址，直接申请 d-cache
        paddr <= {2'h0, vaddr};
        // pma 检查
    end
    else if (tlb_hit) begin
        if (tlb_pte) begin
            // TLB 翻译，直接申请 d-cache
            paddr <= {tlb_out[31:10], vaddr[9:0]};
            // pma 检查
        end
        else begin
            // 权限错误，直接响应
            paddr <= {tlb_out[31:10], vaddr[9:0]};
            page_fault <= 1'h1;
        end
    end
    else if (pwc_hit) begin
        if (pwc_npte) begin
            // 填充 TLB，申请 d-cache
            tlb_pwc_fill <= 1'h1;
            fill_src <= 1'h0;
            paddr <= {pwc_out[31:10], vaddr[19:10]};
            // pma 检查
        end
        else if (pwc_pte) begin
            // PWC 翻译，直接申请 d-cache
            paddr <= {pwc_out[31:20], vaddr[19:0]};
            // pma 检查
        end
        else begin
            // 权限错误，直接响应
            paddr <= {pwc_out[31:20], vaddr[19:0]};
            page_fault <= 1'h1;
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
