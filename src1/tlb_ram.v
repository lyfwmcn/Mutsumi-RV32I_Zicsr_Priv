`timescale 1ns / 1ns

module tlb_ram (
    input              clk,
    input              rst_n,

    input              re,

    input      [4:0]   tlb_raddr,
    output     [31:0]  tlb_out, // 有延迟
    output reg [25:0]  tlb_tag_out,

    input      [1:0]   pwc_raddr,
    output reg [31:0]  pwc_out,
    output reg [17:0]  pwc_tag_out,

    input      [3:0]   tlb_we,
    input      [2:0]   tlb_waddr,
    input      [31:0]  tlb_in,

    input              tlb_tag_we,
    input      [2:0]   tlb_tag_waddr,
    input      [25:0]  tlb_tag_in,

    input      [3:0]   pwc_we,
    input      [31:0]  pwc_in,

    input              pwc_tag_we,
    input      [17:0]  pwc_tag_in
);

// #region TLB
wire [31:0] tlb_outs [3:0];

genvar g_i;
generate
    for (g_i = 0; g_i < 4; g_i = g_i + 1) begin : g_word
        (* ram_style = "distributed" *)
        reg [31:0] tlb [7:0];
        reg [31:0] q;
        always @(posedge clk) begin
            if (re) begin
                q <= tlb[tlb_raddr[4:2]];
            end
            if (tlb_we[g_i]) begin
                tlb[tlb_waddr] <= tlb_in;
            end
        end
        assign tlb_outs[g_i] = q;
    end
endgenerate

reg [1:0] sel;
always @(posedge clk) begin
    if (re) begin
        sel <= tlb_raddr[1:0];
    end
end
assign tlb_out = tlb_outs[sel];
// #endregion

// #region TLB-tag
(* ram_style = "distributed" *)
reg [24:0] tlb_tag [7:0];
reg [7:0]  tlb_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tlb_valid <= 8'h0;
    end
    else begin
        if (tlb_tag_we) begin
            tlb_valid[tlb_tag_waddr] <= tlb_tag_in[0];
        end
    end
end

always @(posedge clk) begin
    if (re) begin
        tlb_tag_out <= {tlb_tag[tlb_raddr[4:2]],tlb_valid[tlb_raddr[4:2]]};
    end
    if (tlb_tag_we) begin
        tlb_tag[tlb_tag_waddr] <= tlb_tag_in[25:1];
    end
end
// #endregion

// #region PWC, PWC-tag
reg [31:0] pwc [3:0];
reg [16:0] pwc_tag;
reg        pwc_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwc_valid <= 1'h0;
    end
    else begin
        if (pwc_tag_we) begin
            pwc_valid <= pwc_tag_in[0];
        end
    end
end

integer i;
always @(posedge clk) begin
    if (re) begin
        pwc_out <= pwc[pwc_raddr];
        pwc_tag_out <= {pwc_tag, pwc_valid};
    end
    if (pwc_tag_we) begin
        pwc_tag <= pwc_tag_in[17:1];
    end
    for (i = 0; i < 4; i = i + 1) begin
        if (pwc_we[i]) begin
            pwc[i] <= pwc_in;
        end
    end
end
// #endregion

endmodule
