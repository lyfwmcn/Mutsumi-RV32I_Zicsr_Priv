`timescale 1ns / 1ns

// 支持综合成 ECP5 真双端口 EBR（DP16KD）的存储结构。
// 32bit 字按字节拆进 9bit lane（第 9 位闲置），两块 18bit EBR 各存两个字(节)：
//   mem0[w][8:0]   = 字 w 的字节 0（字节地址 4w  ）
//   mem0[w][17:9]  = 字 w 的字节 1（字节地址 4w+1）
//   mem1[w][8:0]   = 字 w 的字节 2（字节地址 4w+2）
//   mem1[w][17:9]  = 字 w 的字节 3（字节地址 4w+3）
// EBR 的字节使能粒度是 9bit，因此 8bit 字节必须放进 9bit lane 才能对上写使能。
// 每块 EBR 综合为 DP16KD 真双端口：端口 A 做数据读写（load 读 / store 写，互斥），
// 端口 B 做取指只读。
// 只支持对齐访问
module system_bus #(
    // 串口每 bit 的时钟数：DIV = clk_freq / baud（默认 115200 @25MHz = 217）
    parameter UART_DIV = 25_000_000 / 115_200
) (
    input             clk,
    input             rst_n,
    input             request_valid_data,
    input             request_valid_instr,
    input             request_write_data,
    input      [3:0]  request_en_data,
    input      [31:0] request_addr_data,
    input      [31:0] request_addr_instr,
    input      [31:0] request_data_data,
    output reg        respond_fault_data,
    output reg        respond_fault_instr,
    output reg        respond_valid_data,
    output reg        respond_valid_instr,
    output reg [31:0] respond_data_data,
    output reg [31:0] respond_data_instr,
    // 写 0xFFC~0xFFF 时，把写入字节从串口送出（8N1）
    output            uart_tx
);

// 0 ~ 2^12 - 1（按字索引，字宽 32bit，容量仍为 4KB）
reg [17:0] mem0 [1023:0];
reg [17:0] mem1 [1023:0];


// 程序初始化：bin/mem0.hex、bin/mem1.hex 由 bin/test 生成（见 tools/bin2hex.py）。
// 仿真时在 t=0 读入；综合时作为 EBR 的 INIT 烧进 bitstream（单份来源，仿真与板级同字节）。
initial begin
    $readmemh("build/syn_mem0.hex", mem0, 0, 1023);
    $readmemh("build/syn_mem1.hex", mem1, 0, 1023);
end

reg request_valid_data_reg;
reg request_valid_instr_reg;
reg request_write_data_reg;
reg [3:0] request_en_data_reg;
reg [31:0] request_addr_data_reg;
reg [31:0] request_addr_instr_reg;
reg [31:0] request_data_data_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        request_valid_data_reg <= 1'h0;
        request_valid_instr_reg <= 1'h0;
        request_write_data_reg <= 1'h0;
        request_en_data_reg <= 4'h0;
    end
    else begin
        request_valid_data_reg <= request_valid_data;
        request_valid_instr_reg <= request_valid_instr;
        request_write_data_reg <= request_write_data;
        request_en_data_reg <= request_en_data;
    end
end

// 地址/写数据寄存器不作异步复位：它们会被 EBR 吸收为内部地址/数据输入寄存器，
// yosys 不接受带异步复位（或置位）的 BRAM 地址寄存器。
always @(posedge clk) begin
    request_addr_data_reg <= request_addr_data;
    request_addr_instr_reg <= request_addr_instr;
    request_data_data_reg <= request_data_data;
end

wire respond_fault_data_wire;
wire respond_fault_instr_wire;
wire respond_valid_data_wire;
wire respond_valid_instr_wire;
wire [31:0] respond_data_data_wire;
wire [31:0] respond_data_instr_wire;

assign respond_fault_data_wire = request_addr_data_reg[1:0] != 2'h0 || request_addr_data_reg[31:12] != 20'h0;
assign respond_fault_instr_wire = request_addr_instr_reg[1:0] != 2'h0 || request_addr_instr_reg[31:12] != 20'h0;
assign respond_valid_data_wire = request_valid_data_reg;
assign respond_valid_instr_wire = request_valid_instr_reg;

// 数据字与取指字的 32bit 拼装（字节 3 在最高位，与原 {mem[A+3],..,mem[A]} 一致）
wire [31:0] data_word;
wire [31:0] instr_word;
assign data_word = {mem1[request_addr_data_reg[11:2]][16:9],
                   mem1[request_addr_data_reg[11:2]][7:0],
                   mem0[request_addr_data_reg[11:2]][16:9],
                   mem0[request_addr_data_reg[11:2]][7:0]};
assign instr_word = {mem1[request_addr_instr_reg[11:2]][16:9],
                    mem1[request_addr_instr_reg[11:2]][7:0],
                    mem0[request_addr_instr_reg[11:2]][16:9],
                    mem0[request_addr_instr_reg[11:2]][7:0]};

assign respond_data_data_wire = request_write_data_reg ? 32'h0 :
                                {request_en_data_reg[3] ? data_word[31:24] : 8'h0,
                                request_en_data_reg[2] ? data_word[23:16] : 8'h0,
                                request_en_data_reg[1] ? data_word[15:8] : 8'h0,
                                request_en_data_reg[0] ? data_word[7:0] : 8'h0};
assign respond_data_instr_wire = instr_word;

// store：只在对齐且落在 0x0~0xFFF 内时按字节使能写（错位/越界按访问故障处理，不落盘）
always @(posedge clk) begin
    if (request_valid_data_reg && request_write_data_reg &&
        request_addr_data_reg[1:0] == 2'h0 && request_addr_data_reg[31:12] == 20'h0) begin
        if (request_en_data_reg[0]) begin
            mem0[request_addr_data_reg[11:2]][8:0] <= {1'b0, request_data_data_reg[7:0]};
        end
        if (request_en_data_reg[1]) begin
            mem0[request_addr_data_reg[11:2]][17:9] <= {1'b0, request_data_data_reg[15:8]};
        end
        if (request_en_data_reg[2]) begin
            mem1[request_addr_data_reg[11:2]][8:0] <= {1'b0, request_data_data_reg[23:16]};
        end
        if (request_en_data_reg[3]) begin
            mem1[request_addr_data_reg[11:2]][17:9] <= {1'b0, request_data_data_reg[31:24]};
        end
    end
end

// ---------------------------------------------------------------------------
// 串口输出：对 0xFFC~0xFFF（字 1023）的写，会把「被字节使能选中的字节」按
// lane0→lane3 顺序从 uart_tx 发出（8N1）。整字写(sw)发 4 个字符、字节写(sb)
// 发 1 个（CPU 会把子字的字节摆到对应 lane 并置 en）。
// 发送期间压住 respond_valid_data（背压）→ CPU 等它发完，不会丢字节。
// ---------------------------------------------------------------------------
wire       uart_busy;
reg        uart_start;
reg  [7:0] uart_byte;

uart_tx #(.DIV(UART_DIV)) u_uart_tx (
    .clk  (clk),
    .rst_n(rst_n),
    .start(uart_start),
    .data (uart_byte),
    .busy (uart_busy),
    .tx   (uart_tx)
);

localparam UART_IDLE = 2'd0,
           UART_SEND = 2'd1,
           UART_WAIT = 2'd2;

reg  [1:0]  uart_state;
reg  [31:0] uart_data_q;
reg  [3:0]  uart_en_q;
reg  [1:0]  uart_sel;
reg         uart_done;

// 命中条件与 store 落盘一致：对齐、0x0~0xFFF 内、且是字 1023（字节 0xFFC~0xFFF）
wire uart_hit = request_valid_data_reg && request_write_data_reg &&
                request_addr_data_reg[1:0] == 2'h0 &&
                request_addr_data_reg[31:12] == 20'h0 &&
                request_addr_data_reg[11:2] == 10'h3FF;
// 还有字节没交给 UART → 压住本次响应
wire uart_hold = uart_hit && (request_en_data_reg != 4'h0) && !uart_done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_state  <= UART_IDLE;
        uart_data_q <= 32'h0;
        uart_en_q   <= 4'h0;
        uart_sel    <= 2'd0;
        uart_done   <= 1'b0;
        uart_start  <= 1'b0;
        uart_byte   <= 8'h0;
    end
    else begin
    uart_start <= 1'b0;                            // 单周期脉冲
    if (!request_valid_data_reg) begin
        uart_done <= 1'b0;                         // 请求撤销后才允许下一次
    end
    case (uart_state)
        UART_IDLE: begin
            if (uart_hold) begin
                uart_data_q <= request_data_data_reg;
                uart_en_q   <= request_en_data_reg;
                uart_sel    <= 2'd0;
                uart_state  <= UART_SEND;
            end
        end
        UART_SEND: begin
            if (!uart_en_q[uart_sel]) begin        // 该 lane 未使能 → 跳过
                if (uart_sel == 2'd3) begin
                    uart_state <= UART_IDLE;
                    uart_done  <= 1'b1;
                end
                else begin
                    uart_sel <= uart_sel + 2'd1;
                end
            end
            else if (!uart_busy) begin
                uart_byte  <= uart_data_q[uart_sel*8 +: 8];
                uart_start <= 1'b1;                // 交给 UART
                uart_state <= UART_WAIT;
            end
        end
        default: begin                             // UART_WAIT
            if (uart_busy) begin                   // 已开始发送 → 下一个字节
                if (uart_sel == 2'd3) begin
                    uart_state <= UART_IDLE;
                    uart_done  <= 1'b1;
                end
                else begin
                    uart_sel   <= uart_sel + 2'd1;
                    uart_state <= UART_SEND;
                end
            end
        end
    endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_valid_instr <= 1'h0;
        respond_fault_instr <= 1'h0;
        respond_data_instr <= 32'h0;
    end
    else begin
        respond_valid_instr <= respond_valid_instr_wire;
        if (request_valid_instr_reg) begin
            respond_fault_instr <= respond_fault_instr_wire;
            respond_data_instr <= respond_data_instr_wire;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        respond_fault_data <= 1'h0;
        respond_valid_data <= 1'h0;
        respond_data_data <= 32'h0;
    end
    else if (request_valid_data_reg && !uart_hold) begin
        respond_fault_data <= respond_fault_data_wire;
        respond_valid_data <= 1'h1;
        respond_data_data <= respond_data_data_wire;
    end
    else if (!request_valid_data_reg) begin
        respond_fault_data <= 1'h0;
        respond_valid_data <= 1'h0;
        respond_data_data <= 32'h0;
    end
end

endmodule
