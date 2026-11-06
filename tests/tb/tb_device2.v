// device2（存储器子系统）测试：路由 + 全局仲裁 + 内部集成 PHY 的 sdram_ctr + SDRAM 模型
//   ROM 区（0~4K）→ ROM 口      pma==1 → SDRAM      pma==2 → uart（写）/ 8 拍 0
//   pma==0 → null                d/i 同时请求 → device2 里全局仲裁（d 优先）
`timescale 1ns/1ps

module tb_device2;
reg clk = 1'b0;
reg rst_n = 1'b0;
always #10 clk = ~clk;      // 50 MHz

// 请求方（[1]=d_cache [0]=i_cache）
reg  [1:0]   rq_v = 2'h0;
reg  [32:0]  addr_v [1:0];
reg          dc_we = 1'b0;
reg  [15:0]  dc_be = 16'hffff;
reg  [127:0] dc_data = 128'h0;
wire [1:0]   busy_v, rv_v;
wire [31:0]  rd_v;
wire         uart_tx;

// SDRAM 引脚
wire        sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n;
wire [1:0]  sdram_ba, sdram_dm;
wire [12:0] sdram_a;
wire [15:0] sdram_dq;

device2 #(.SYS_HZ(50_000_000)) u (
    .clk(clk), .rst_n(rst_n),

    .d_cache_request_valid(rq_v[1]), .d_cache_request_we(dc_we), .d_cache_request_be(dc_be),
    .d_cache_request_addr(addr_v[1]), .d_cache_request_data(dc_data),
    .d_cache_request_busy(busy_v[1]), .d_cache_respond_valid(rv_v[1]),
    .d_cache_respond_data(rd_v[1*16 +: 16]),

    .i_cache_request_valid(rq_v[0]), .i_cache_request_addr(addr_v[0]),
    .i_cache_request_busy(busy_v[0]), .i_cache_respond_valid(rv_v[0]),
    .i_cache_respond_data(rd_v[0*16 +: 16]),

    .sdram_cke(sdram_cke), .sdram_cs_n(sdram_cs_n), .sdram_ras_n(sdram_ras_n),
    .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_ba(sdram_ba),
    .sdram_a(sdram_a), .sdram_dq(sdram_dq), .sdram_dm(sdram_dm),

    .uart_tx(uart_tx), .uart_rx(1'b1)
);

sdram_model #(.AW(16)) u_dram (
    .clk(clk), .cke(sdram_cke), .cs_n(sdram_cs_n), .ras_n(sdram_ras_n),
    .cas_n(sdram_cas_n), .we_n(sdram_we_n), .ba(sdram_ba), .a(sdram_a),
    .dm(sdram_dm), .dq(sdram_dq)
);

integer pass = 0, fail = 0;
`define CK(c, m)  if (c) begin pass = pass + 1; $display("  [PASS] %s", m); end \
                  else begin fail = fail + 1; $display("  [FAIL] %s", m); end

integer n, k;
reg [15:0] cap [0:7];
reg [15:0] cap2 [0:7];
reg [9:0]  ucap;
reg [127:0] exp_img [0:255];
initial $readmemh("build/boot.hex", exp_img);

localparam [32:0] A_SDRAM = 33'h0000_0800;   // byte 0x1000
localparam [32:0] A_DEV   = 33'h0100_0000;   // byte 0x200_0000
localparam [32:0] A_NULL  = 33'h0200_0000;   // byte 0x400_0000

// 发一次请求：等空闲 -> 打一拍 valid -> 收 8 拍
task automatic xfer(input integer p, input we, input [32:0] a, input [127:0] wd,
                    output integer beats);
    begin
        n = 0;
        while (busy_v[p] && n < 500) begin @(negedge clk); n = n + 1; end
        @(negedge clk);
        addr_v[p] = a; dc_we = we; dc_data = wd; dc_be = 16'hffff; rq_v[p] = 1'b1;
        @(negedge clk);
        rq_v[p] = 1'b0;
        k = 0; n = 0;
        while (k < 8 && n < 500) begin
            if (rv_v[p]) begin cap[k] = rd_v[p*16 +: 16]; k = k + 1; end
            @(negedge clk);
            n = n + 1;
        end
        beats = k;
    end
endtask

// 写（没有响应），等 busy 落下
task automatic wr(input [32:0] a, input [127:0] wd);
    begin
        n = 0;
        while (busy_v[1] && n < 500) begin @(negedge clk); n = n + 1; end
        @(negedge clk);
        addr_v[1] = a; dc_we = 1'b1; dc_data = wd; dc_be = 16'hffff; rq_v[1] = 1'b1;
        @(negedge clk);
        rq_v[1] = 1'b0; dc_we = 1'b0;
        n = 0;
        while (busy_v[1] && n < 500) begin @(negedge clk); n = n + 1; end
    end
endtask

reg [127:0] pat;
integer beats;

initial begin
    for (k = 0; k < 2; k = k + 1) addr_v[k] = 33'h0;
    repeat (10) @(negedge clk);
    rst_n = 1'b1;
    repeat (9000) @(negedge clk);     // 等 SDRAM 初始化（控制器上电先等 0x1fff 拍）

    // ========== 1) ROM 区：i_cache 读 0x0000 ==========
    $display("");
    $display("== ROM 区：i_cache 读 ==");
    xfer(0, 1'b0, 33'h0, 128'h0, beats);
    `CK(beats == 8, "ROM 读回 8 拍")
    `CK(cap[0] === exp_img[0][15:0] && cap[1] === exp_img[0][31:16], "ROM 行 0 前 2 拍正确")
    `CK(cap[7] === exp_img[0][127:112], "ROM 行 0 第 8 拍正确")

    // ========== 2) ROM 区：d_cache 读 0x0FF0 ==========
    $display("");
    $display("== ROM 区：d_cache 读 0x0FF0 ==");
    xfer(1, 1'b0, 33'h0000_07F8, 128'h0, beats);
    `CK(beats == 8, "ROM 读回 8 拍")
    `CK(cap[0] === exp_img[255][15:0], "ROM 行 255 第 1 拍正确")

    // ========== 3) ROM 区写：丢弃 ==========
    $display("");
    $display("== ROM 区写：丢弃 ==");
    wr(33'h0000_0080, 128'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff);   // byte 0x0100
    xfer(1, 1'b0, 33'h0000_0080, 128'h0, beats);
    `CK(beats == 8 && cap[0] === exp_img[16][15:0], "写没生效，读回仍是 ROM 内容")

    // ========== 4) SDRAM 写后读回 ==========
    $display("");
    $display("== SDRAM：d 写后读回 ==");
    pat = 128'hdead_beef_1234_5678_9abc_def0_1111_2222;
    wr(A_SDRAM, pat);
    xfer(1, 1'b0, A_SDRAM, 128'h0, beats);
    `CK(beats == 8, "读回 8 拍")
    `CK({cap[7], cap[6], cap[5], cap[4], cap[3], cap[2], cap[1], cap[0]} === pat,
       "写进去的数据原样读回")

    // ========== 5) i_cache 读同一地址 ==========
    $display("");
    $display("== SDRAM：i 读同一地址 ==");
    xfer(0, 1'b0, A_SDRAM, 128'h0, beats);
    `CK(beats == 8, "i 读回 8 拍")
    `CK({cap[7], cap[6], cap[5], cap[4], cap[3], cap[2], cap[1], cap[0]} === pat,
       "i 读到同样的数据")

    // ========== 6) pma==0 → null ==========
    $display("");
    $display("== pma==0 → null（8 拍 0）==");
    xfer(1, 1'b0, A_NULL, 128'h0, beats);
    `CK(beats == 8, "读回 8 拍")
    `CK(cap[0] === 16'h0 && cap[7] === 16'h0, "全 0")

    // ========== 7) pma==2 写 → uart ==========
    $display("");
    $display("== pma==2 写 → uart ==");
    n = 0;
    while (busy_v[1] && n < 200) begin @(negedge clk); n = n + 1; end
    @(negedge clk);
    dc_we = 1'b1; dc_be = 16'h0001;
    dc_data = 128'h0; dc_data[7:0] = 8'hA5;
    addr_v[1] = A_DEV; rq_v[1] = 1'b1;
    @(negedge clk);
    rq_v[1] = 1'b0; dc_we = 1'b0;
    // 抓 UART 帧（DIV=434 -> 434 拍/位）
    n = 0;
    while (!u.u_uart.request_busy && n < 50) begin @(negedge clk); n = n + 1; end
    for (k = 0; k < 10; k = k + 1) begin
        ucap[k] = uart_tx;
        repeat (434) @(negedge clk);
    end
    `CK(ucap == {1'b1, 8'hA5, 1'b0}, "UART 帧 = 停止位+A5+起始位")

    // ========== 8) 仲裁：d / i 同拍读不同地址 ==========
    $display("");
    $display("== 仲裁：d / i 同时读 ==");
    wr(A_SDRAM, pat);                                  // 0x1000 = pat
    wr(33'h0000_0810, ~pat);                           // 0x1020 = ~pat
    n = 0;
    while ((busy_v[0] || busy_v[1]) && n < 500) begin @(negedge clk); n = n + 1; end
    @(negedge clk);
    addr_v[1] = A_SDRAM;        rq_v[1] = 1'b1;        // d
    addr_v[0] = 33'h0000_0810;  rq_v[0] = 1'b1;        // i（同拍）
    @(negedge clk);
    rq_v[1] = 1'b0; rq_v[0] = 1'b0;
    // 先收 d 的 8 拍，再收 i 的 8 拍（仲裁先 d 后 i）
    k = 0; n = 0;
    while (k < 8 && n < 500) begin
        if (rv_v[1]) begin cap[k] = rd_v[1*16 +: 16]; k = k + 1; end
        @(negedge clk); n = n + 1;
    end
    `CK({cap[7], cap[6], cap[5], cap[4], cap[3], cap[2], cap[1], cap[0]} === pat,
       "d 拿到自己的数据")
    k = 0; n = 0;
    while (k < 8 && n < 500) begin
        if (rv_v[0]) begin cap2[k] = rd_v[0*16 +: 16]; k = k + 1; end
        @(negedge clk); n = n + 1;
    end
    `CK({cap2[7], cap2[6], cap2[5], cap2[4], cap2[3], cap2[2], cap2[1], cap2[0]} === ~pat,
       "i 拿到自己的数据（没有串包）")

    $display("");
    $display("============================================");
    $display("  通过 %0d 项，失败 %0d 项", pass, fail);
    $display("============================================");
    $finish;
end

initial begin
    #5_000_000;
    $display("!! 看门狗超时  通过 %0d 失败 %0d", pass, fail);
    $finish;
end

endmodule
