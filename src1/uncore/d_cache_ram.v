`timescale 1ns / 1ns

/**
 * raddr/waddr: addr[11:4]
 * tag: dirty + paddr[33:12] + valid
 * valid 依靠 EBR 初始化
 * d_cache_we: 高 2 位为行选择，低 2 位为行内选择
 */
module d_cache_ram (
    input              clk,

    input              d_cache_re,
    input      [7:0]   d_cache_raddr,
    output     [23:0]  d_cache_tag0,
    output     [23:0]  d_cache_tag1,
    output     [23:0]  d_cache_tag2,
    output     [23:0]  d_cache_tag3,
    output     [127:0] d_cache_rdata0,
    output     [127:0] d_cache_rdata1,
    output     [127:0] d_cache_rdata2,
    output     [127:0] d_cache_rdata3,

    input      [3:0]   d_cache_tag_we,
    input      [7:0]   d_cache_waddr,
    input      [15:0]  d_cache_we,
    input      [23:0]  d_cache_tag_in,
    input      [31:0]  d_cache_in
);

wire [127:0] d_cache_out [3:0];
assign d_cache_rdata0 = d_cache_out[0];
assign d_cache_rdata1 = d_cache_out[1];
assign d_cache_rdata2 = d_cache_out[2];
assign d_cache_rdata3 = d_cache_out[3];

wire [23:0] d_cache_tag_out [3:0];
assign d_cache_tag0 = d_cache_tag_out[0];
assign d_cache_tag1 = d_cache_tag_out[1];
assign d_cache_tag2 = d_cache_tag_out[2];
assign d_cache_tag3 = d_cache_tag_out[3];

genvar g_i, g_j;
generate
    for (g_i = 0; g_i < 4; g_i = g_i + 1) begin : g_line

        (* ram_style = "block" *)
        reg [23:0] tag [255:0];
        integer k;
        initial begin
            for (k = 0; k < 256; k = k + 1) begin
                tag[k] = 24'h0;
            end
        end
        reg [23:0] q;
        always @(posedge clk) begin
            if (d_cache_re) begin
                q <= tag[d_cache_raddr];
            end
            if (d_cache_tag_we[g_i]) begin
                tag[d_cache_waddr] <= d_cache_tag_in;
            end
        end
        assign d_cache_tag_out[g_i] = q;

        for (g_j = 0; g_j < 4; g_j = g_j + 1) begin : g_word
            (* ram_style = "block" *)
            reg [31:0] mem [255:0];
            reg [31:0] q;
            always @(posedge clk) begin
                if (d_cache_re) begin
                    q <= mem[d_cache_raddr];
                end
                if (d_cache_we[{g_i[1:0], g_j[1:0]}]) begin
                    mem[d_cache_waddr] <= d_cache_in;
                end
            end
            assign d_cache_out[g_i][{g_j[1:0], 5'h0} +: 32] = q;
        end

    end
endgenerate

endmodule
