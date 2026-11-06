`timescale 1ns/1ps
// 只测 sdram_ctr1（内部已集成 PHY）+ SDRAM 模型：
//   - 上电初始化序列
//   - 128 bit 写 → 8 个 16 bit 读回
//   - 跨 bank/row 的预充电与重新激活
//   - 读响应 valid 的拍数
module tb_sdram_ctr1;

reg clk = 1'b0;
reg rst_n = 1'b0;
always #10 clk = ~clk;      // 50 MHz

wire        sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n;
wire [1:0]  sdram_ba, sdram_dm;
wire [12:0] sdram_a;
wire [15:0] sdram_dq;

reg         d_valid = 1'b0;
reg         d_we = 1'b0;
reg  [15:0] d_be = 16'hffff;
reg  [23:0] d_addr = 24'h0;
reg  [127:0] d_data = 128'h0;
wire        d_busy, d_rv;
wire [15:0] d_rd;

sdram_ctr1 u_ctr (
    .clk(clk), .rst_n(rst_n),
    .request_valid(d_valid), .request_we(d_we), .request_be(d_be),
    .request_addr(d_addr), .request_data(d_data),
    .request_busy(d_busy), .respond_valid(d_rv), .respond_data(d_rd),
    .sdram_cke(sdram_cke), .sdram_cs_n(sdram_cs_n), .sdram_ras_n(sdram_ras_n),
    .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_ba(sdram_ba),
    .sdram_dm(sdram_dm), .sdram_a(sdram_a), .sdram_dq(sdram_dq)
);

sdram_model #(.AW(16)) u_dram (
    .clk(clk), .cke(sdram_cke), .cs_n(sdram_cs_n), .ras_n(sdram_ras_n),
    .cas_n(sdram_cas_n), .we_n(sdram_we_n), .ba(sdram_ba), .a(sdram_a),
    .dm(sdram_dm), .dq(sdram_dq)
);

integer pass = 0, fail = 0, valid_beats = 0;
integer fresh_cnt = 0, fresh_before;
`define CK(c, m) if (c) begin pass = pass + 1; $display("  [PASS] %s", m); end \
                  else begin fail = fail + 1; $display("  [FAIL] %s", m); end

reg [127:0] wdata, wdata_n;
reg [127:0] test_data;
reg [23:0]  base_addr;
integer i, j, k;

// 统计 respond_valid 连续拍数（每次读应正好 8 拍）
always @(posedge clk) begin
    if (d_rv) valid_beats = valid_beats + 1;
    else      valid_beats = 0;
end

// 统计 SDRAM 引脚上的 AUTO REFRESH 命令
always @(posedge clk) begin
    if (!sdram_cs_n && !sdram_ras_n && !sdram_cas_n && sdram_we_n)
        fresh_cnt = fresh_cnt + 1;
end

task automatic do_write(input [23:0] addr, input [15:0] be, input [127:0] data);
    begin
        while (d_busy) @(negedge clk);
        @(negedge clk);
        d_addr = addr; d_data = data; d_we = 1'b1; d_be = be; d_valid = 1'b1;
        @(negedge clk);
        d_valid = 1'b0;
        k = 0;
        while (d_busy && k < 200) begin @(negedge clk); k = k + 1; end
        if (k >= 200) $display("  [timeout] 写 %h 不结束", addr);
    end
endtask

task automatic do_read(input [23:0] addr, output [15:0] data);
    begin
        while (d_busy) @(negedge clk);
        @(negedge clk);
        d_addr = addr; d_we = 1'b0; d_valid = 1'b1;
        @(negedge clk);
        d_valid = 1'b0;
        k = 0;
        while (k < 4000 && !d_rv) begin @(negedge clk); k = k + 1; end
        if (!d_rv) begin
            $display("  [timeout] 读 %h 等不到响应", addr);
            data = 16'hxxxx;
        end
        else begin
            data = d_rd;
            $display("  [信息] 读 %h 用了 %0d 拍，数据 %h", addr, k, d_rd);
        end
        while (d_rv) @(negedge clk);
    end
endtask

reg [15:0] rd_val;

initial begin
    wdata   = 128'h0706_0504_0302_0100_1918_1716_1514_1312;
    wdata_n = ~wdata;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (20000) @(posedge clk);     // 等初始化完成（reset 后 0x1fff 拍等待）

    // bank0 / row0
    do_write(24'h000000, 16'hffff, wdata);
    $display("  [dbg] mem[0..7]: %h %h %h %h", u_dram.mem[0], u_dram.mem[1], u_dram.mem[2], u_dram.mem[3]);
    for (i = 0; i < 8; i = i + 1) begin
        do_read(i, rd_val);
        `CK(rd_val == wdata[i*16 +: 16], "读回数据一致")
    end

    // 换到 bank2 / row1（地址 bit[4:3] 是 bank）
    do_write(24'h002000, 16'hffff, wdata_n);
    for (i = 0; i < 8; i = i + 1) begin
        do_read(24'h002000 + i, rd_val);
        `CK(rd_val == wdata_n[i*16 +: 16], "换行后读回一致")
    end

    // 再回到原来的行
    do_read(24'h000000, rd_val);
    `CK(rd_val == wdata[15:0], "回到原行仍能读对")

    // 字节掩码：只写低字节，另一侧保持
    do_read(24'h000000 + 1, rd_val);
    do_write(24'h000000, 16'h0001, 128'h0000_0000_0000_0000_0000_0000_0000_00aa);
    do_read(24'h000000, rd_val);
    `CK(rd_val[7:0] == 8'haa && rd_val[15:8] == wdata[15:8], "DM 低字节写、高字节保持")

    // 地址低 3 位非 0：burst 在 8 个 16 bit 字内绕回。
    // 语义和旧 sdram_ctr 一致：request_data 的 lane 按块内位置编号，
    // addr[2:0] 只是起始 lane。addr=5 时第 0 拍取 lane5，第 7 拍绕回 lane4。
    do_write(24'h000005, 16'hffff, wdata);
    $display("  [dbg] 非对齐写后 mem[0..7]: %h %h %h %h %h %h %h %h",
             u_dram.mem[0], u_dram.mem[1], u_dram.mem[2], u_dram.mem[3],
             u_dram.mem[4], u_dram.mem[5], u_dram.mem[6], u_dram.mem[7]);
    do_read(24'h000005, rd_val);
    `CK(rd_val == wdata[5*16 +: 16], "非对齐 burst 从 lane5 开始")
    do_read(24'h000007, rd_val);
    `CK(rd_val == wdata[7*16 +: 16], "非对齐 burst 第 2 拍")
    do_read(24'h000004, rd_val);
    `CK(rd_val == wdata[4*16 +: 16], "非对齐 burst 绕回 lane4")

    // 长时间空闲：确认周期刷新仍在跑
    fresh_before = fresh_cnt;
    repeat (1200) @(posedge clk);
    $display("  [信息] 空闲 1200 拍内 AUTO REFRESH 次数：%0d", fresh_cnt - fresh_before);
    `CK(fresh_cnt - fresh_before >= 2, "空闲时周期刷新正常")

    // 压力：跨 4 个 bank、4 个 row、2 个列块反复读写
    for (i = 0; i < 32; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1)
            test_data[j*16 +: 16] = (i * 8 + j) & 16'hffff;
        base_addr = ((i / 4) % 4) << 11 | ((i / 16) % 4) << 5 | (i % 4) << 3;
        do_write(base_addr, 16'hffff, test_data);
        for (j = 0; j < 8; j = j + 1) begin
            do_read(base_addr + j, rd_val);
            `CK(rd_val == test_data[j*16 +: 16], "压力读写一致")
        end
    end

    // 读响应拍数检查（最后一次读）
    `CK(valid_beats == 8, "读响应 valid 正好 8 拍")

    $display("");
    $display("========== TB: 通过 %0d 项，失败 %0d 项 ==========", pass, fail);
    $finish;
end

endmodule
