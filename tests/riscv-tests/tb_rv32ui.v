`timescale 1ns / 1ps
// rv32ui 最小运行环境：
//   - core + uncore + 简单 16 位存储模型（同时服务 I/D 口）
//   - 地址 0 放 trampoline: j 0x10000
//   - 测试镜像加载到 0x10000，固定 64KB
//   - tohost 放在 0x02000000，写进去的值被 latch，TB 轮询
module tb_rv32ui;

reg clk = 1'b0;
reg rst_n = 1'b0;
always #5 clk = ~clk;

localparam integer MEM_HALFWORDS = 131072;     // 256KB 字节空间
reg [15:0] mem [0:MEM_HALFWORDS-1];

// ---------------- 核心 ----------------
wire        d_valid, d_busy, d_af, d_pf, d_rv;
wire [1:0]  d_op;
wire [3:0]  d_be;
wire [29:0] d_addr;
wire [31:0] d_wdata, d_rd;
wire        i_valid, i_busy, i_af, i_pf, i_rv;
wire [29:0] i_addr;
wire [31:0] i_rd;
wire [1:0]  privilege;
wire [31:0] satp;

// uncore <-> memory
wire        d_req_valid, d_req_we;
wire [15:0] d_req_be;
wire [32:0] d_req_addr;
wire [127:0] d_req_wdata;
wire        i_req_valid;
wire [32:0] i_req_addr;

core u_core (
    .clk(clk), .rst_n(rst_n),
    .external_interrupt_clear(1'b0), .external_interrupt_set(1'b0),
    .timer_interrupt_clear(1'b0),    .timer_interrupt_set(1'b0),
    .d_core_respond_access_fault(d_af), .d_core_respond_page_fault(d_pf),
    .d_core_respond_valid(d_rv), .d_core_respond_data(d_rd),
    .d_core_request_busy(d_busy),
    .d_core_request_valid(d_valid), .d_core_request_op(d_op), .d_core_request_be(d_be),
    .d_core_request_addr(d_addr), .d_core_request_data(d_wdata),
    .i_core_respond_access_fault(i_af), .i_core_request_busy(i_busy),
    .i_core_respond_page_fault(i_pf), .i_core_respond_valid(i_rv), .i_core_respond_data(i_rd),
    .i_core_request_valid(i_valid), .i_core_request_addr(i_addr),
    .satp(satp), .privilege(privilege)
);

uncore u_uncore (
    .clk(clk), .rst_n(rst_n),
    .privilege(privilege), .satp(satp),
    .d_core_request_valid(d_valid), .d_core_request_op(d_op), .d_core_request_be(d_be),
    .d_core_request_vaddr(d_addr), .d_core_request_data(d_wdata),
    .d_core_respond_access_fault(d_af), .d_core_request_busy(d_busy),
    .d_core_respond_page_fault(d_pf), .d_core_respond_valid(d_rv), .d_core_respond_data(d_rd),
    .i_core_request_valid(i_valid), .i_core_request_vaddr(i_addr),
    .i_core_respond_access_fault(i_af), .i_core_request_busy(i_busy),
    .i_core_respond_page_fault(i_pf), .i_core_respond_valid(i_rv), .i_core_respond_data(i_rd),
    .d_ram_request_busy(d_req_busy), .d_ram_respond_valid(d_req_rv), .d_ram_respond_data(d_req_rd),
    .d_ram_request_valid(d_req_valid), .d_ram_request_we(d_req_we), .d_ram_request_be(d_req_be),
    .d_ram_request_addr(d_req_addr), .d_ram_request_data(d_req_wdata),
    .i_ram_request_busy(i_req_busy), .i_ram_respond_valid(i_req_rv), .i_ram_respond_data(i_req_rd),
    .i_ram_request_valid(i_req_valid), .i_ram_request_addr(i_req_addr)
);

// ---------------- 存储模型 ----------------
reg        d_req_busy, d_req_rv;
reg [15:0] d_req_rd;
reg        i_req_busy, i_req_rv;
reg [15:0] i_req_rd;

reg        d_run, i_run;
reg [3:0]  d_beat, i_beat;
reg [32:0] d_addr_q, i_addr_q;
reg        d_we_q;
reg [15:0] d_be_q;
reg [127:0] d_wdata_q;

// tohost
reg        tohost_valid = 1'b0;
reg [31:0] tohost_data  = 32'h0;

integer k;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_req_busy <= 1'b0; d_req_rv <= 1'b0; d_run <= 1'b0; d_beat <= 4'h0;
        i_req_busy <= 1'b0; i_req_rv <= 1'b0; i_run <= 1'b0; i_beat <= 4'h0;
        d_we_q <= 1'b0; d_be_q <= 16'h0; d_wdata_q <= 128'h0;
    end
    else begin
        // ---------- D 侧 ----------
        d_req_rv <= 1'b0;
        if (!d_run) begin
            if (d_req_valid && !d_req_busy) begin
                d_run <= 1'b1; d_req_busy <= 1'b1; d_beat <= 4'h0;
                d_addr_q <= d_req_addr;
                d_we_q <= d_req_we;
                d_be_q <= d_req_be;
                d_wdata_q <= d_req_wdata;
            end
        end
        else if (d_we_q) begin
            // tohost / fromhost：Device 区，latch 低 32 位
            if (d_addr_q == 33'h0100_0000) begin
                tohost_valid <= 1'b1;
                tohost_data  <= d_wdata_q[31:0];
            end
            else begin
                for (k = 0; k < 16; k = k + 1)
                    if (d_be_q[k])
                        mem[d_addr_q[15:0] + k/2][(k%2)*8 +: 8] <= d_wdata_q[k*8 +: 8];
            end
            d_run <= 1'b0; d_req_busy <= 1'b0;
        end
        else begin
            d_req_rv <= 1'b1;
            // tohost/fromhost 读回 0；其余读正常内存
            if (d_addr_q[32:2] == 31'h0040_0000)
                d_req_rd <= 16'h0;
            else
                d_req_rd <= mem[{d_addr_q[15:3], 3'h0} + ((d_addr_q[2:0] + d_beat) & 3'h7)];
            if (d_beat == 4'h7) begin d_run <= 1'b0; d_req_busy <= 1'b0; end
            d_beat <= d_beat + 4'h1;
        end

        // ---------- I 侧 ----------
        i_req_rv <= 1'b0;
        if (!i_run) begin
            if (i_req_valid && !i_req_busy) begin
                i_run <= 1'b1; i_req_busy <= 1'b1; i_beat <= 4'h0;
                i_addr_q <= i_req_addr;
            end
        end
        else begin
            i_req_rv <= 1'b1;
            i_req_rd <= mem[{i_addr_q[15:3], 3'h0} + ((i_addr_q[2:0] + i_beat) & 3'h7)];
            if (i_beat == 4'h7) begin i_run <= 1'b0; i_req_busy <= 1'b0; end
            i_beat <= i_beat + 4'h1;
        end
    end
end

// ---------------- 测试启动 ----------------
reg [1023:0] testhex;
integer cycles;
initial begin
    if (!$value$plusargs("TESTHEX=%s", testhex)) begin
        $display("ERROR: +TESTHEX=<file> required");
        $finish;
    end

    for (k = 0; k < MEM_HALFWORDS; k = k + 1) mem[k] = 16'h0;
    // trampoline @ 0: j 0x10000 -> 0x0001006f
    mem[0] = 16'h006f;
    mem[1] = 16'h0001;

    $readmemh(testhex, mem, 16'h8000, 16'hffff);

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (4) @(negedge clk);

    cycles = 0;
    while (!tohost_valid && cycles < 300000) begin
        @(negedge clk);
        cycles = cycles + 1;
    end

    if (tohost_valid) begin
        if (tohost_data == 32'h1)
            $display("PASS: testnum=1 cycles=%0d", cycles);
        else
            $display("FAIL: testnum=%0d (0x%08h) cycles=%0d pc=%08h",
                     tohost_data, tohost_data, cycles, u_core.if_stage.pc);
    end
    else begin
        $display("TIMEOUT: cycles=%0d pc=%08h priv=%0d",
                 cycles, u_core.if_stage.pc, privilege);
    end
    $finish;
end

endmodule
