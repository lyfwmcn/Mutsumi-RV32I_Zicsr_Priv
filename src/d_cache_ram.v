`timescale 1ns / 1ns

module d_cache_ram (
    input              clk,
    input              rst_n,

    input              op,
    input      [1:0]   privilege,
    input      [31:0]  satp,

    input              re,
    input              d_cache_flush,
    input              d_pwc_tlb_flush,
    input      [31:0]  addr,    // 以 4B 为单位的地址

    output reg [31:0]  d_cache_out0,
    output reg [31:0]  d_cache_out1,
    output reg [31:0]  d_cache_out2,
    output reg [31:0]  d_cache_out3,

    output reg [127:0] d_cache_line_out0,
    output reg [127:0] d_cache_line_out1,
    output reg [127:0] d_cache_line_out2,
    output reg [127:0] d_cache_line_out3,

    output reg [25:0]  d_cache_tag_out0,
    output reg [25:0]  d_cache_tag_out1,
    output reg [25:0]  d_cache_tag_out2,
    output reg [25:0]  d_cache_tag_out3,

    output reg [31:0]  d_pwc_out,
    output reg [17:0]  d_pwc_tag_out,

    output reg [31:0]  d_tlb_out,
    output reg [47:0]  d_tlb_tag_out,

    output reg         d_cache_hit0,
    output reg         d_cache_hit1,
    output reg         d_cache_hit2,
    output reg         d_cache_hit3,
    output reg [1:0]   d_cache_index0,
    output reg [1:0]   d_cache_index1,
    output reg [1:0]   d_cache_index2,
    output reg [1:0]   d_cache_index3,
    output reg         d_pwc_hit,
    output reg         d_pwc_pte,
    output reg         d_pwc_npte,
    output reg         d_tlb_hit,
    output reg         d_tlb_pte,

    input      [3:0]   d_cache_be,
    input      [31:0]  d_cache_in,
    input      [1:0]   d_cache_windex,
    input      [7:0]   d_cache_waddr,    // 以 4B 为单位的地址

    input              d_cache_tag_we,
    input      [25:0]  d_cache_tag_in,
    input      [1:0]   d_cache_tag_windex,
    input      [5:0]   d_cache_tag_waddr,    // 以 4B 为单位的地址

    input      [3:0]   d_pwc_be,
    input      [31:0]  d_pwc_in,
    input      [1:0]   d_pwc_waddr,
    input              d_pwc_tag_we,
    input      [17:0]  d_pwc_tag_in,

    input      [3:0]   d_tlb_be,
    input      [31:0]  d_tlb_in,
    input      [4:0]   d_tlb_waddr,
    input              d_tlb_tag_we,
    input      [47:0]  d_tlb_tag_in,
    input      [2:0]   d_tlb_tag_waddr
);

wire [29:0] vaddr = addr[29:0];

// ----------------------EBR 部分----------------------
wire [127:0] d_cache_out [3:0];

genvar g_i, g_j;
generate
    for (g_i = 0; g_i < 4; g_i = g_i + 1) begin : g_line
        for (g_j = 0; g_j < 4; g_j = g_j + 1) begin : g_word
            (* ram_style = "block" *)
            reg [31:0] mem [63:0];
            reg [31:0] q;
            always @(posedge clk) begin
                if (re) begin
                    q <= mem[vaddr[7:2]];
                end
                if (d_cache_windex == g_i && d_cache_waddr[1:0] == g_j) begin
                    if (d_cache_be[0]) mem[d_cache_waddr[7:2]][7:0]   <= d_cache_in[7:0];
                    if (d_cache_be[1]) mem[d_cache_waddr[7:2]][15:8]  <= d_cache_in[15:8];
                    if (d_cache_be[2]) mem[d_cache_waddr[7:2]][23:16] <= d_cache_in[23:16];
                    if (d_cache_be[3]) mem[d_cache_waddr[7:2]][31:24] <= d_cache_in[31:24];
                end
            end
            assign d_cache_out[g_i][{g_j[1:0], 5'h0} +: 32] = q;
        end
    end
endgenerate

reg [1:0] sel;

always @(posedge clk) begin
    if (re) begin
        sel <= vaddr[1:0];
    end
end

always @(*) begin
    d_cache_out0      = d_cache_out[0][{sel, 5'h0} +: 32];
    d_cache_out1      = d_cache_out[1][{sel, 5'h0} +: 32];
    d_cache_out2      = d_cache_out[2][{sel, 5'h0} +: 32];
    d_cache_out3      = d_cache_out[3][{sel, 5'h0} +: 32];
    d_cache_line_out0 = d_cache_out[0];
    d_cache_line_out1 = d_cache_out[1];
    d_cache_line_out2 = d_cache_out[2];
    d_cache_line_out3 = d_cache_out[3];
end
// ----------------------------------------------------

// ---------------------LUTRAM部分---------------------
reg [24:0]  d_cache_tag0 [63:0];
reg [24:0]  d_cache_tag1 [63:0];
reg [24:0]  d_cache_tag2 [63:0];
reg [24:0]  d_cache_tag3 [63:0];

reg [63:0]  d_cache_tag_valid0;
reg [63:0]  d_cache_tag_valid1;
reg [63:0]  d_cache_tag_valid2;
reg [63:0]  d_cache_tag_valid3;

reg [127:0] d_pwc_data;
reg [16:0]  d_pwc_tag;
reg         d_pwc_tag_valid;

reg [127:0] d_tlb_data  [7:0];
reg [46:0]  d_tlb_tag   [7:0];
reg [7:0]   d_tlb_tag_valid;

wire [25:0] nxt_d_cache_tag_out0 = {d_cache_tag0[vaddr[7:2]], d_cache_tag_valid0[vaddr[7:2]]};
wire [25:0] nxt_d_cache_tag_out1 = {d_cache_tag1[vaddr[7:2]], d_cache_tag_valid1[vaddr[7:2]]};
wire [25:0] nxt_d_cache_tag_out2 = {d_cache_tag2[vaddr[7:2]], d_cache_tag_valid2[vaddr[7:2]]};
wire [25:0] nxt_d_cache_tag_out3 = {d_cache_tag3[vaddr[7:2]], d_cache_tag_valid3[vaddr[7:2]]};
wire [31:0] nxt_d_pwc_out        = d_pwc_data[{vaddr[21:20], 5'h0} +: 32];
wire [17:0] nxt_d_pwc_tag_out    = {d_pwc_tag, d_pwc_tag_valid};
wire [31:0] nxt_d_tlb_out        = d_tlb_data[vaddr[14:12]][{vaddr[11:10], 5'h0} +: 32];
wire [47:0] nxt_d_tlb_tag_out    = {d_tlb_tag[vaddr[14:12]], d_tlb_tag_valid[vaddr[14:12]]};

wire [31:0] paddr0 = {2'h0, vaddr};
wire [31:0] paddr1 = {nxt_d_tlb_out[31:10], vaddr[9:0]};
wire [31:0] paddr2 = {nxt_d_pwc_out[31:20], vaddr[19:0]};
wire [31:0] paddr3 = addr;

// 要复位部分
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_cache_tag_valid0 <= 64'h0;
        d_cache_tag_valid1 <= 64'h0;
        d_cache_tag_valid2 <= 64'h0;
        d_cache_tag_valid3 <= 64'h0;
        d_pwc_tag_valid    <= 1'h0;
        d_tlb_tag_valid    <= 8'h0;
    end
    else begin
        if (d_cache_flush) begin
            d_cache_tag_valid0 <= 64'h0;
            d_cache_tag_valid1 <= 64'h0;
            d_cache_tag_valid2 <= 64'h0;
            d_cache_tag_valid3 <= 64'h0;
        end
        else if (d_cache_tag_we) begin
            case (d_cache_tag_windex)
                2'h0: d_cache_tag_valid0[d_cache_tag_waddr] <= d_cache_tag_in[0];
                2'h1: d_cache_tag_valid1[d_cache_tag_waddr] <= d_cache_tag_in[0];
                2'h2: d_cache_tag_valid2[d_cache_tag_waddr] <= d_cache_tag_in[0];
                2'h3: d_cache_tag_valid3[d_cache_tag_waddr] <= d_cache_tag_in[0];
                default: ;
            endcase
        end
        if (d_pwc_tlb_flush) begin
            d_pwc_tag_valid <= 1'h0;
            d_tlb_tag_valid <= 8'h0;
        end
        else begin
            if (d_pwc_tag_we) begin
                d_pwc_tag_valid <= d_pwc_tag_in[0];
            end
            if (d_tlb_tag_we) begin
                d_tlb_tag_valid[d_tlb_tag_waddr] <= d_tlb_tag_in[0];
            end
        end
    end
end

integer i;
always @(posedge clk) begin
    if (d_cache_tag_we) begin
        case (d_cache_tag_windex)
            2'h0: begin
                d_cache_tag0[d_cache_tag_waddr] <= d_cache_tag_in[25:1];
            end
            2'h1: begin
                d_cache_tag1[d_cache_tag_waddr] <= d_cache_tag_in[25:1];
            end
            2'h2: begin
                d_cache_tag2[d_cache_tag_waddr] <= d_cache_tag_in[25:1];
            end
            2'h3: begin
                d_cache_tag3[d_cache_tag_waddr] <= d_cache_tag_in[25:1];
            end
            default: ;
        endcase
    end
    for (i = 0; i < 4; i = i + 1) begin
        if (d_pwc_be[i]) begin
            d_pwc_data[{d_pwc_waddr, i[1:0], 3'h0} +: 8] <= d_pwc_in[{i[1:0], 3'h0} +: 8];
        end
    end
    if (d_pwc_tag_we) begin
        d_pwc_tag <= d_pwc_tag_in[17:1];
    end
    for (i = 0; i < 4; i = i + 1) begin
        if (d_tlb_be[i]) begin
            d_tlb_data[{d_tlb_waddr[4:2]}][{d_tlb_waddr[1:0], i[1:0], 3'h0} +: 8] <= d_tlb_in[{i[1:0], 3'h0} +: 8];
        end
    end
    if (d_tlb_tag_we) begin
        d_tlb_tag[d_tlb_tag_waddr] <= d_tlb_tag_in[47:1];
    end
end

function automatic d_cache_hit;
    input [31:0] paddr;
    begin
        d_cache_hit = (nxt_d_cache_tag_out3[0] && nxt_d_cache_tag_out3[24:1] == paddr[31:8]) ||
                      (nxt_d_cache_tag_out2[0] && nxt_d_cache_tag_out2[24:1] == paddr[31:8]) ||
                      (nxt_d_cache_tag_out1[0] && nxt_d_cache_tag_out1[24:1] == paddr[31:8]) ||
                      (nxt_d_cache_tag_out0[0] && nxt_d_cache_tag_out0[24:1] == paddr[31:8]);
    end
endfunction

function automatic [1:0] d_cache_index;
    input [31:0] paddr;
    begin
        d_cache_index = nxt_d_cache_tag_out3[0] && nxt_d_cache_tag_out3[24:1] == paddr[31:8] ? 2'h3 :
                        nxt_d_cache_tag_out2[0] && nxt_d_cache_tag_out2[24:1] == paddr[31:8] ? 2'h2 :
                        nxt_d_cache_tag_out1[0] && nxt_d_cache_tag_out1[24:1] == paddr[31:8] ? 2'h1 :
                        2'h0;
    end
endfunction

always @(posedge clk) begin
    if (re) begin
        d_cache_tag_out0 <= nxt_d_cache_tag_out0;
        d_cache_tag_out1 <= nxt_d_cache_tag_out1;
        d_cache_tag_out2 <= nxt_d_cache_tag_out2;
        d_cache_tag_out3 <= nxt_d_cache_tag_out3;
        d_pwc_out        <= nxt_d_pwc_out;
        d_pwc_tag_out    <= nxt_d_pwc_tag_out;
        d_tlb_out        <= nxt_d_tlb_out;
        d_tlb_tag_out    <= nxt_d_tlb_tag_out;
        d_cache_hit0     <= d_cache_hit(paddr0);
        d_cache_hit1     <= d_cache_hit(paddr1);
        d_cache_hit2     <= d_cache_hit(paddr2);
        d_cache_hit3     <= d_cache_hit(paddr3);
        d_cache_index0   <= d_cache_index(paddr0);
        d_cache_index1   <= d_cache_index(paddr1);
        d_cache_index2   <= d_cache_index(paddr2);
        d_cache_index3   <= d_cache_index(paddr3);
        d_pwc_hit        <= nxt_d_pwc_tag_out[0] &&
                            nxt_d_pwc_tag_out[17:10] == vaddr[29:22] &&
                            (nxt_d_pwc_tag_out[9:1] == satp[30:22] ||
                            nxt_d_pwc_out[5]);
        d_pwc_pte        <= nxt_d_pwc_out[0] &&
                            (nxt_d_pwc_out[1] || !nxt_d_pwc_out[2]) &&
                            nxt_d_pwc_out[19:10] == 10'h0 &&
                            (op ? nxt_d_pwc_out[2] : nxt_d_pwc_out[1]) &&
                            nxt_d_pwc_out[4] != privilege[0];
        d_pwc_npte       <= nxt_d_pwc_out[0] &&
                            !(nxt_d_pwc_out[1] || nxt_d_pwc_out[2] ||
                            nxt_d_pwc_out[3] || nxt_d_pwc_out[4] ||
                            nxt_d_pwc_out[6] || nxt_d_pwc_out[7]);
        d_tlb_hit        <= nxt_d_tlb_tag_out[0] &&
                            nxt_d_tlb_tag_out[25:11] == vaddr[29:15] &&
                            (nxt_d_tlb_tag_out[10:2] == satp[30:22] ||
                            nxt_d_tlb_tag_out[1] ||
                            nxt_d_tlb_out[5]);
        d_tlb_pte        <= nxt_d_tlb_out[0] &&
                            (nxt_d_tlb_out[1] || !nxt_d_tlb_out[2]) &&
                            (op ? nxt_d_tlb_out[2] : nxt_d_tlb_out[1]) &&
                            nxt_d_tlb_out[4] != privilege[0];
    end
end

// ----------------------------------------------------

endmodule
