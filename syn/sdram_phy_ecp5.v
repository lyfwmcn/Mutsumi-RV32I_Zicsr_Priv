// SDRAM 物理层（ECP5 PIC / IOLOGIC 版本）
//
// 目的：把 SDRAM 的所有信号寄存器放进 ECP5 的 I/O 单元（PIC 里的 IOLOGIC），
//       而不是留在 fabric 里。这样：
//         - pad 的 clock-to-out 固定且很小，地址/命令/数据之间的偏斜可控；
//         - 读数据由 IOB 输入寄存器采样，pad → FF 的路径最短，
//           配合 180° 的 sdram_clk（数据在 FPGA 时钟沿之间翻转）留出半个周期的建立时间。
//
// 原语说明（yosys 的 ecp5 techmap 会把它们变成 TRELLIS_FF + syn_useioff，
// nextpnr-ecp5 再把相邻的 FF 打包进 PIO 的 IOLOGIC）：
//   OFS1P3DX(CD, D, SP, SCLK, Q)  输出寄存器，CD 复位清 0（DX = reset to 0）
//   OFS1P3BX(PD, D, SP, SCLK, Q)  输出寄存器，PD 复位置 1（BX = reset to 1）
//   IFS1P3BX(PD, D, SP, SCLK, Q)  输入寄存器
//   BB(I, T, O, B)                双向缓冲，T=1 时 B 为高阻
// 这里 SP(CE) 恒为 1，PD/CD 恒为 0，复位值交给 GSR。
//
// 时序影响（重要）：本模块给所有输出加 1 拍延迟，读回的数据也晚 1 拍，
// 所以 sdram_ctr 里的 tCL 要相应加大（读窗口后移）。
`timescale 1ns / 1ns

module sdram_phy_ecp5 #(
    // 1 = 用 ECP5 原语，把寄存器打包进 I/O 单元（PIC/IOLOGIC）
    // 0 = 同样逻辑，但用普通 fabric 寄存器（对照用，便于定位问题）
    parameter USE_PIC = 1
) (
    input  clk,
    input  rst_n,

    // ---------------- 来自 sdram_ctr ----------------
    input         cke_in,
    input         cs_n_in,
    input         ras_n_in,
    input         cas_n_in,
    input         we_n_in,
    input  [1:0]  ba_in,
    input  [12:0] a_in,
    input  [1:0]  dm_in,
    input  [15:0] dq_out_in,   // 写数据（组合，和命令同拍）
    input         dq_oe_in,    // 1: 驱动 DQ
    output [15:0] dq_in,       // 寄存后的读数据

    // ---------------- 到 SDRAM 引脚 ----------------
    output        sdram_cke,
    output        sdram_cs_n,
    output        sdram_ras_n,
    output        sdram_cas_n,
    output        sdram_we_n,
    output [1:0]  sdram_ba,
    output [12:0] sdram_a,
    output [1:0]  sdram_dm,
    inout  [15:0] sdram_dq
);

// 三态控制也打一拍，和写数据对齐（否则数据晚一拍、松三态早一拍，会掐掉最后一拍）
reg dq_oe_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) dq_oe_r <= 1'h0;
    else        dq_oe_r <= dq_oe_in;
end

generate
if (USE_PIC) begin : g_pic
    // 输出寄存器：CKE 复位置 0（初始化期间保持低）
    OFS1P3DX u_cke (.CD(1'b0), .D(cke_in), .SP(1'b1), .SCLK(clk), .Q(sdram_cke));

    // 复位值为 1 的输出：片选、命令（NOP = 全 1）
    OFS1P3BX u_cs  (.PD(1'b0), .D(cs_n_in),  .SP(1'b1), .SCLK(clk), .Q(sdram_cs_n));
    OFS1P3BX u_ras (.PD(1'b0), .D(ras_n_in), .SP(1'b1), .SCLK(clk), .Q(sdram_ras_n));
    OFS1P3BX u_cas (.PD(1'b0), .D(cas_n_in), .SP(1'b1), .SCLK(clk), .Q(sdram_cas_n));
    OFS1P3BX u_we  (.PD(1'b0), .D(we_n_in),  .SP(1'b1), .SCLK(clk), .Q(sdram_we_n));

    genvar i;
    for (i = 0; i < 2; i = i + 1) begin : g_ba
        OFS1P3DX u_ba (.CD(1'b0), .D(ba_in[i]), .SP(1'b1), .SCLK(clk), .Q(sdram_ba[i]));
        OFS1P3DX u_dm (.CD(1'b0), .D(dm_in[i]), .SP(1'b1), .SCLK(clk), .Q(sdram_dm[i]));
    end
    for (i = 0; i < 13; i = i + 1) begin : g_a
        OFS1P3DX u_a (.CD(1'b0), .D(a_in[i]), .SP(1'b1), .SCLK(clk), .Q(sdram_a[i]));
    end

    // DQ：输出寄存器 + 输入寄存器 + 双向缓冲
    for (i = 0; i < 16; i = i + 1) begin : g_dq
        wire dq_out_r;
        wire dq_pad_i;

        OFS1P3DX u_out (.CD(1'b0), .D(dq_out_in[i]), .SP(1'b1), .SCLK(clk), .Q(dq_out_r));
        IFS1P3BX u_in  (.PD(1'b0), .D(dq_pad_i),     .SP(1'b1), .SCLK(clk), .Q(dq_in[i]));
        BB       u_bb  (.I(dq_out_r), .T(!dq_oe_r),  .O(dq_pad_i), .B(sdram_dq[i]));
    end
end
else begin : g_ff
    // 普通寄存器版：逻辑完全一样，只是不打包进 I/O 单元
    reg        r_cke, r_cs_n, r_ras_n, r_cas_n, r_we_n;
    reg [1:0]  r_ba, r_dm;
    reg [12:0] r_a;
    reg [15:0] r_dq_out, r_dq_in;

    always @(posedge clk) begin
        r_cke   <= cke_in;
        r_cs_n  <= cs_n_in;
        r_ras_n <= ras_n_in;
        r_cas_n <= cas_n_in;
        r_we_n  <= we_n_in;
        r_ba    <= ba_in;
        r_dm    <= dm_in;
        r_a     <= a_in;
        r_dq_out<= dq_out_in;
        r_dq_in <= sdram_dq;
    end

    assign sdram_cke   = r_cke;
    assign sdram_cs_n  = r_cs_n;
    assign sdram_ras_n = r_ras_n;
    assign sdram_cas_n = r_cas_n;
    assign sdram_we_n  = r_we_n;
    assign sdram_ba    = r_ba;
    assign sdram_dm    = r_dm;
    assign sdram_a     = r_a;
    assign dq_in       = r_dq_in;
    assign sdram_dq    = dq_oe_r ? r_dq_out : 16'hzzzz;
end
endgenerate

endmodule
