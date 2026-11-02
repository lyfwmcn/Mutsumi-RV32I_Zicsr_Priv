// uart_tx_unit 行为测试：读返回 8 拍 0；写发送第一个 be=1 的字节；busy 全程为 1
`timescale 1ns/1ps

module tb_uart;
reg clk = 1'b0;
reg rst_n = 1'b0;
always #5 clk = ~clk;

reg         req_valid = 1'b0;
reg         req_we    = 1'b0;
reg  [15:0] req_be    = 16'h0;
reg  [127:0] req_data = 128'h0;
wire        busy;
wire        resp_valid;
wire [15:0] resp_data;
wire        tx;

uart_tx_unit #(.DIV(4)) u (
    .clk(clk), .rst_n(rst_n),
    .request_valid(req_valid), .request_we(req_we),
    .request_be(req_be), .request_data(req_data),
    .request_busy(busy), .respond_valid(resp_valid), .respond_data(resp_data),
    .tx(tx)
);

integer pass = 0, fail = 0;
`define CK(c, m)  if (c) begin pass = pass + 1; $display("  [PASS] %s", m); end \
                  else begin fail = fail + 1; $display("  [FAIL] %s", m); end

integer i, k, n;
reg [9:0]  cap;
reg [7:0]  want;

// 发一次请求（1 拍 valid）
task do_req(input we, input [15:0] be, input [127:0] d);
    begin
        while (busy) @(negedge clk);      // busy 为 0 才发
        @(negedge clk);
        req_valid = 1'b1; req_we = we; req_be = be; req_data = d;
        @(negedge clk);
        req_valid = 1'b0;
    end
endtask

// 在 busy 期间按位采样 10 位（DIV=4，每 4 拍一位）
task cap_frame;
    begin
        n = 0;
        while (!busy && n < 100) begin @(negedge clk); n = n + 1; end
        for (k = 0; k < 10; k = k + 1) begin
            cap[k] = tx;
            `CK(busy === 1'b1, "发送期间 busy=1")
            repeat (4) @(negedge clk);
        end
        n = 0;
        while (busy && n < 100) begin @(negedge clk); n = n + 1; end
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // ---------- 1) 读：应连续 8 拍返回 0 ----------
    $display("");
    $display("== 读：返回 8 拍 0 ==");
    do_req(1'b0, 16'h0, 128'h0);
    n = 0; i = 0;
    while (busy && n < 100) begin
        if (resp_valid) begin
            i = i + 1;
            if (resp_data !== 16'h0000) i = i + 100;   // 记录错误
        end
        @(negedge clk);
        n = n + 1;
    end
    `CK(i == 8, "读响应正好 8 拍且数据全 0")
    `CK(!busy && !resp_valid, "读结束后 busy/respond_valid 都回 0")

    // ---------- 2) 写：be 里第一个 1 的字节 ----------
    $display("");
    $display("== 写：发送第一个 be=1 的字节 ==");
    // 字节 9 = 0x5A，字节 10 = 0xA5；be 同时置 9、10 → 应发下标 9
    req_data = 128'h0;
    req_data[8*9  +: 8] = 8'h5A;
    req_data[8*10 +: 8] = 8'hA5;
    do_req(1'b1, (16'h1 << 9) | (16'h1 << 10), req_data);
    cap_frame;
    want = 8'h5A;
    `CK(cap == {1'b1, want, 1'b0}, "发送的帧 = 停止位+0x5A+起始位")
    `CK(cap[0] === 1'b0, "起始位 = 0")

    // ---------- 3) 写：只有 be[0] ----------
    $display("");
    $display("== 写：只使能字节 0 ==");
    req_data = 128'h0;
    req_data[7:0] = 8'hC3;
    do_req(1'b1, 16'h0001, req_data);
    cap_frame;
    want = 8'hC3;
    `CK(cap == {1'b1, want, 1'b0}, "发送的帧 = 停止位+0xC3+起始位")

    // ---------- 4) 写：最高字节 be[15] ----------
    $display("");
    $display("== 写：只使能字节 15 ==");
    req_data = 128'h0;
    req_data[8*15 +: 8] = 8'h81;
    do_req(1'b1, 16'h8000, req_data);
    cap_frame;
    want = 8'h81;
    `CK(cap == {1'b1, want, 1'b0}, "发送的帧 = 停止位+0x81+起始位")

    // ---------- 5) 写：be == 0，不应发送 ----------
    $display("");
    $display("== 写：be=0 不发送 ==");
    do_req(1'b1, 16'h0, 128'h0);
    n = 0;
    while (busy && n < 20) begin @(negedge clk); n = n + 1; end
    `CK(n <= 2, "be=0 时 busy 只持续 1~2 拍")
    `CK(tx === 1'b1, "be=0 时 tx 保持空闲高电平")

    // ---------- 6) busy 期间不再接受新请求 ----------
    $display("");
    $display("== busy 期间的新请求被忽略 ==");
    req_data = 128'h0; req_data[7:0] = 8'h11;
    do_req(1'b1, 16'h0001, req_data);          // 开始发 0x11
    @(negedge clk);
    // 在忙的时候再打一个请求（应被忽略）
    req_valid = 1'b1; req_we = 1'b1; req_be = 16'h0001;
    req_data = 128'h0; req_data[7:0] = 8'h22;
    repeat (6) @(negedge clk);
    req_valid = 1'b0;
    n = 0;
    while (busy && n < 100) begin @(negedge clk); n = n + 1; end
    repeat (6) @(negedge clk);
    `CK(!busy, "忙时打的请求没有启动第二次发送")

    $display("");
    $display("============================================");
    $display("  通过 %0d 项，失败 %0d 项", pass, fail);
    $display("============================================");
    $finish;
end

initial begin
    #200_000;
    $display("!! 看门狗超时  通过 %0d 失败 %0d", pass, fail);
    $finish;
end

endmodule
