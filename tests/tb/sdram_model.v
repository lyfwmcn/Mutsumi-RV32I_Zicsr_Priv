// 简化 SDRAM 行为模型（只实现 sdram_ctr 用到的命令）
//   - 时序按 ctr 的 localparam：tCL=0、tRCD=0、tRP=0（命令后下一拍就出/收数据）
//   - 支持：ACTIVE / READ / WRITE / PRECHARGE / AUTO_REFRESH / LMR / NOP
//   - BL=8，读：命令后连续 8 拍从 dq 输出；写：命令拍(第0拍)+后 7 拍采样 dq
//   - 地址映射与 ctr 一致：{row, col[8:3], bank, col[2:0]}（bank 在 bit[4:3] 交错）
//   - dm 为高表示该字节被屏蔽
`timescale 1ns / 1ps

module sdram_model #(
    parameter AW = 16          // 内部存储器字数（2 字节为单位），64K 字 = 128KB
) (
    input         clk,
    input         cke,
    input         cs_n,
    input         ras_n,
    input         cas_n,
    input         we_n,
    input  [1:0]  ba,
    input  [12:0] a,
    input  [1:0]  dm,
    inout  [15:0] dq
);

    reg [15:0] mem [0:(1<<AW)-1];

    reg [12:0] row [3:0];
    reg        act [3:0];

    localparam [2:0] C_LMR = 3'b000,
                     C_REF = 3'b001,
                     C_PRE = 3'b010,
                     C_ACT = 3'b011,
                     C_WR  = 3'b100,
                     C_RD  = 3'b101,
                     C_NOP = 3'b111;

    wire       cmd_valid = !cs_n;
    wire [2:0] cmd       = {ras_n, cas_n, we_n};

    // 读突发
    reg        rd_on;
    reg [2:0]  rd_beat;
    reg [23:0] rd_base;

    // 写突发（wr_beat 从 1 开始，第 0 拍在命令译码里处理）
    reg        wr_on;
    reg [2:0]  wr_beat;
    reg [23:0] wr_base;

    function [23:0] lin;
        input [12:0] r;
        input [1:0]  b;
        input [8:0]  c;
        begin
            lin = {r, c[8:3], b, c[2:0]};
        end
    endfunction

    function [23:0] beat_addr;
        input [23:0] base;
        input [2:0]  n;
        begin
            beat_addr = {base[23:3], base[2:0] + n}; // 块内回绕
        end
    endfunction

    reg        rd_pend;   // READ 命令后 1 拍才开始出数据（对应模式寄存器 CL=2）
    wire [23:0] rd_idx = beat_addr(rd_base, rd_beat);
    wire [23:0] wr_idx = beat_addr(wr_base, wr_beat);

    // 读数据在时钟沿之后半个周期才变化（真实芯片：SDRAM 时钟 180° 相位 + tAC）
    // 这样 I/O 输入寄存器（PHY 里的 IFS）在沿上采到的就是稳定的那一拍数据
    localparam real TAC = 10.0;   // ns（仿真时钟 20ns = 50MHz 时正好半个周期）
    assign #(TAC) dq = rd_on ? mem[rd_idx[AW-1:0]] : 16'hzzzz;

    integer i;
    initial begin
        for (i = 0; i < (1<<AW); i = i + 1) mem[i] = 16'h0;
    end

    initial rd_pend = 1'b0;

    always @(posedge clk) begin
        // ---- 读数据流 ----
        if (rd_on) begin
            if (rd_beat == 3'h7) rd_on   <= 1'b0;
            else                 rd_beat <= rd_beat + 3'h1;
        end

        // ---- 写数据流：第 1..7 拍 ----
        if (wr_on) begin
            if (!dm[0]) mem[wr_idx[AW-1:0]][7:0]  <= dq[7:0];
            if (!dm[1]) mem[wr_idx[AW-1:0]][15:8] <= dq[15:8];
            if (wr_beat == 3'h7) wr_on   <= 1'b0;
            else                 wr_beat <= wr_beat + 3'h1;
        end

        // ---- 命令译码 ----
        if (cmd_valid) begin
            case (cmd)
                C_ACT: begin
                    row[ba] <= a;
                    act[ba] <= 1'b1;
                end
                C_RD: begin
                    // 命令后下一拍开始出数据（已按上板实测校准）
                    rd_on   <= 1'b1;
                    rd_beat <= 3'h0;
                    rd_base <= lin(row[ba], ba, a[8:0]);
                end
                C_WR: begin
                    wr_on   <= 1'b1;
                    wr_beat <= 3'h1;
                    wr_base <= lin(row[ba], ba, a[8:0]);
                    // 第 0 拍
                    if (!dm[0]) mem[lin(row[ba], ba, a[8:0])[AW-1:0]][7:0]  <= dq[7:0];
                    if (!dm[1]) mem[lin(row[ba], ba, a[8:0])[AW-1:0]][15:8] <= dq[15:8];
                end
                C_PRE, C_REF, C_LMR: begin
                    if (cmd == C_PRE) begin
                        act[0] <= 1'b0; act[1] <= 1'b0; act[2] <= 1'b0; act[3] <= 1'b0;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule
