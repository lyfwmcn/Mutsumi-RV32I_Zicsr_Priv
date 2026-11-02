// null_device 测试：读 8 拍 0；写 1 拍完成、无响应
// 接口和 boot_rom / sdram_ctr 一致（单口从设备）
`timescale 1ns/1ps

module tb_null;
reg clk = 1'b0;
reg rst_n = 1'b0;
always #5 clk = ~clk;

reg         v  = 1'b0;
reg         we = 1'b0;
reg  [15:0] be = 16'hffff;
reg  [23:0] a  = 24'h0;
reg  [127:0] wd = 128'h0;
wire        busy, rv;
wire [15:0] rd;

null_device u (
    .clk(clk), .rst_n(rst_n),
    .request_valid(v), .request_we(we), .request_be(be),
    .request_addr(a), .request_data(wd),
    .request_busy(busy), .respond_valid(rv), .respond_data(rd)
);

integer pass = 0, fail = 0;
`define CK(c, m)  if (c) begin pass = pass + 1; $display("  [PASS] %s", m); end \
                  else begin fail = fail + 1; $display("  [FAIL] %s", m); end

integer n, k, beats, bad, bcyc, nbusy_err;

// 一次读：统计响应拍数、非 0 拍数、响应期间 busy 不为 1 的拍数
task automatic rd_once(output integer beats, output integer bad, output integer nbusy_err);
    begin
        beats = 0; bad = 0; nbusy_err = 0;
        n = 0;
        while (busy && n < 100) begin @(negedge clk); n = n + 1; end
        @(negedge clk);
        v = 1'b1; we = 1'b0;
        @(negedge clk);
        v = 1'b0;
        n = 0;
        while ((busy || rv) && n < 100) begin
            if (rv) begin
                beats = beats + 1;
                if (rd !== 16'h0000) bad = bad + 1;
                if (busy !== 1'b1)   nbusy_err = nbusy_err + 1;
            end
            @(negedge clk);
            n = n + 1;
        end
    end
endtask

// 一次写：统计 busy 拍数和响应拍数
task automatic wr_once(output integer bcyc, output integer rbeats);
    begin
        bcyc = 0; rbeats = 0;
        n = 0;
        while (busy && n < 100) begin @(negedge clk); n = n + 1; end
        @(negedge clk);
        v = 1'b1; we = 1'b1; be = 16'hffff;
        wd = 128'hdead_beef_1234_5678_9abc_def0_1111_2222;
        @(negedge clk);
        v = 1'b0; we = 1'b0;
        n = 0;
        while ((busy || rv) && n < 20) begin
            if (busy) bcyc   = bcyc + 1;
            if (rv)   rbeats = rbeats + 1;
            @(negedge clk);
            n = n + 1;
        end
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // ---------- 1) 读：8 拍 0 ----------
    $display("");
    $display("== 读：连续 8 拍返回 0 ==");
    rd_once(beats, bad, nbusy_err);
    $display("   beats=%0d bad=%0d", beats, bad);
    `CK(beats == 8, "读返回正好 8 拍")
    `CK(bad == 0, "8 拍数据全为 0")
    `CK(nbusy_err == 0, "响应期间 busy 一直为 1")
    `CK(!busy, "结束后 busy 回 0")

    // ---------- 2) 写：1 拍完成、无响应 ----------
    $display("");
    $display("== 写：1 拍完成、无响应 ==");
    wr_once(bcyc, beats);
    $display("   busy 拍数=%0d 响应拍数=%0d", bcyc, beats);
    `CK(bcyc <= 2, "写 busy ≤ 2 拍")
    `CK(beats == 0, "写不产生响应")
    `CK(!busy, "写结束后 busy 回 0")

    // ---------- 3) 背靠背两次读 ----------
    $display("");
    $display("== 背靠背两次读 ==");
    rd_once(beats, bad, nbusy_err);
    `CK(beats == 8 && bad == 0, "第一次读正常")
    rd_once(beats, bad, nbusy_err);
    `CK(beats == 8 && bad == 0, "紧接着第二次读正常")

    // ---------- 4) 响应期间再打请求：不会多出响应 ----------
    $display("");
    $display("== 响应期间打请求应被忽略 ==");
    n = 0;
    while (busy && n < 100) begin @(negedge clk); n = n + 1; end
    @(negedge clk);
    v = 1'b1; we = 1'b0;
    @(negedge clk);
    v = 1'b0;
    beats = 0; n = 0;
    while ((busy || rv) && n < 100) begin
        if (rv) beats = beats + 1;
        if (beats == 2 || beats == 3) v = 1'b1;   // 响应中途再打一次
        if (beats == 4)               v = 1'b0;
        @(negedge clk);
        n = n + 1;
    end
    v = 1'b0;
    `CK(beats == 8, "只回 8 拍，没有因为中途请求而多回")
    `CK(!busy, "最后回到空闲")

    $display("");
    $display("============================================");
    $display("  通过 %0d 项，失败 %0d 项", pass, fail);
    $display("============================================");
    $finish;
end

initial begin
    #100_000;
    $display("!! 看门狗超时  通过 %0d 失败 %0d", pass, fail);
    $finish;
end

endmodule
