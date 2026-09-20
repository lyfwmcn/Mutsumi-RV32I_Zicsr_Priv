`timescale 1ns / 1ns

// 8.7 ns
// 需保证 alu_ctr[3:0]: 4'h0-4'h8, 4'hd
module alu (
    input  [5:0]  alu_ctr,
    input  [31:0] alu_in_a,
    input  [31:0] alu_in_b,
    output        zf,
    output        cf,
    output        sf,
    output        of,
    output [31:0] alu_out
);

// 翻转/不翻转的 a 操作数
wire [31:0] _alu_in_a;
assign _alu_in_a = alu_ctr[4] == 1'h0 ? alu_in_a : ~alu_in_a;
// 翻转/不翻转的 b 操作数
wire [31:0] _alu_in_b;
assign _alu_in_b = alu_ctr[5] == 1'h0 ? alu_in_b : ~alu_in_b;

wire [31:0] result [7:0];

wire sub;
assign sub = alu_ctr[3];

// 纯加法链：操作数与 sub 无关，尽早开算（sub 的高扇出不再进进位链）
wire [32:0] add_ext;
assign add_ext = {1'b0, _alu_in_a} + {1'b0, _alu_in_b};

// 有符号/无符号比较、以及减法共用同一条链：a - b
wire [32:0] diff_ext;
assign diff_ext = {1'b0, _alu_in_a} + {1'b0, ~_alu_in_b} + 33'h1;
wire [31:0] diff;
assign diff = diff_ext[31:0];
wire borrow;
assign borrow = ~diff_ext[32];

// result[0]：加法选 add_ext，减法直接复用 diff
wire [31:0] sum;
assign sum = sub ? diff : add_ext[31:0];

wire sltu;
assign sltu = borrow;
wire slt;
assign slt = (_alu_in_a[31] ^ _alu_in_b[31]) ? _alu_in_a[31] : diff[31];

assign result[0] = sum;
assign result[1] = _alu_in_a << _alu_in_b[4:0];
assign result[2] = {31'h0, slt};
assign result[3] = {31'h0, sltu};
assign result[4] = _alu_in_a ^ _alu_in_b;
assign result[5] = sub == 1'h0 ? _alu_in_a >> _alu_in_b[4:0] : $unsigned($signed(_alu_in_a) >>> _alu_in_b[4:0]);
assign result[6] = _alu_in_a | _alu_in_b;
assign result[7] = _alu_in_a & _alu_in_b;

assign zf = sum == 32'h0;
// 与原 cf 完全等价：原实现先做 32 位的 (~_alu_in_b + 1)（丢弃其进位）再相加，
// 因此当 _alu_in_b == 0 时，它的 cout 与整条 a-b 链的进位相差一位。
wire neg_cy;
assign neg_cy = sub & (|_alu_in_b);
assign cf = (sub ? diff_ext[32] : add_ext[32]) ^ neg_cy;
assign sf = sum[31];
// 与原 of 完全等价：原式用 __alu_in_b[31]（即 (~_alu_in_b + 1) 的 MSB）。
// 这里用 31 位或归约推导该 MSB：sub 时 MSB(~x+1) = x[31] ^ |x[30:0]。
wire c31;
assign c31 = _alu_in_b[31] ^ (sub & (|_alu_in_b[30:0]));
assign of = (_alu_in_a[31] & c31 & ~sum[31]) | (~_alu_in_a[31] & ~c31 & sum[31]);
assign alu_out = result[alu_ctr[2:0]];

endmodule
