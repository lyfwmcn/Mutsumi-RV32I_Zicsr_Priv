`timescale 1ns / 1ns

// 3.9 ns
module csr_read (
    input      [11:0] csr_rd,
    input      [31:0] raw_csr_in,
    output reg [31:0] csr_in
);

// ---- 各 CSR 的格式化"视图"，并行计算并共享重复逻辑 ----
wire [31:0] v_sstatus;
wire [31:0] v_sie;
wire [31:0] v_tvec;         // 0x105 / 0x305
wire [31:0] v_epc;          // 0x141 / 0x341
wire [31:0] v_cause;        // 0x142 / 0x342
wire [31:0] v_sip;
wire [31:0] v_mstatus;
wire [31:0] v_medeleg;
wire [31:0] v_mideleg_mie;  // 0x303 / 0x304
wire [31:0] v_mip;

assign v_sstatus = {12'h0, raw_csr_in[19:18], 9'h0, raw_csr_in[8], 2'h0, raw_csr_in[5], 3'h0, raw_csr_in[1], 1'h0};
assign v_sie = {22'h0, raw_csr_in[9], 3'h0, raw_csr_in[5], 3'h0, raw_csr_in[1], 1'h0};
assign v_tvec = {raw_csr_in[31:2], raw_csr_in[1:0] >= 2'h2 ? 2'h0 : raw_csr_in[1:0]};
assign v_epc = {raw_csr_in[31:2], 2'h0};
assign v_cause = {raw_csr_in[31], 27'h0, raw_csr_in[31] == 1'h0 ? (raw_csr_in[3:0] == 4'ha || raw_csr_in[3:0] == 4'he ? 4'h3 : raw_csr_in[3:0]) : (raw_csr_in[3:0] != 4'h1 && raw_csr_in[3:0] != 4'h3 && raw_csr_in[3:0] != 4'h5 && raw_csr_in[3:0] != 4'h7 && raw_csr_in[3:0] != 4'h9 && raw_csr_in[3:0] != 4'hb ? 4'h3 : raw_csr_in[3:0])};
assign v_sip = {30'h0, raw_csr_in[1], 1'h0};
assign v_mstatus = {9'h0, raw_csr_in[22:17], 4'h0, raw_csr_in[12:11] == 2'h2 ? 2'h3 : raw_csr_in[12:11], 2'h0, raw_csr_in[8:7], 1'h0, raw_csr_in[5], 1'h0, raw_csr_in[3], 1'h0, raw_csr_in[1], 1'h0};
assign v_medeleg = {16'h0, raw_csr_in[15], 1'h0, raw_csr_in[13:11], 1'h0, raw_csr_in[9:0]};
assign v_mideleg_mie = {20'h0, raw_csr_in[11], 1'h0, raw_csr_in[9], 1'h0, raw_csr_in[7], 1'h0, raw_csr_in[5], 1'h0, raw_csr_in[3], 1'h0, raw_csr_in[1], 1'h0};
assign v_mip = {28'h0, raw_csr_in[3], 1'h0, raw_csr_in[1], 1'h0};

// 用 unique case 明确"互斥+完备"，让综合建并行（平衡）mux，而不是串行优先链。
always @(*) begin
    case (csr_rd)
        12'h100: csr_in = v_sstatus;
        12'h104: csr_in = v_sie;
        12'h105: csr_in = v_tvec;
        12'h140: csr_in = raw_csr_in;
        12'h141: csr_in = v_epc;
        12'h142: csr_in = v_cause;
        12'h143: csr_in = raw_csr_in;
        12'h144: csr_in = v_sip;
        12'h180: csr_in = raw_csr_in;
        12'h300: csr_in = v_mstatus;
        12'h302: csr_in = v_medeleg;
        12'h303: csr_in = v_mideleg_mie;
        12'h304: csr_in = v_mideleg_mie;
        12'h305: csr_in = v_tvec;
        12'h340: csr_in = raw_csr_in;
        12'h341: csr_in = v_epc;
        12'h342: csr_in = v_cause;
        12'h343: csr_in = raw_csr_in;
        12'h344: csr_in = v_mip;
        default: csr_in = 32'h0;
    endcase
end

endmodule
