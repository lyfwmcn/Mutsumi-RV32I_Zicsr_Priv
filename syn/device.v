`timescale 1ns / 1ns

module device #(
    parameter SYS_HZ = 50_000_000
) (
    input              clk,
    input              rst_n,

    input              d_uncore_request_valid,
    input              d_uncore_request_we,
    input      [15:0]  d_uncore_request_be,
    input      [31:0]  d_uncore_request_addr,
    input      [127:0] d_uncore_request_data,
    output             d_uncore_request_busy,
    output reg         d_uncore_respond_valid,
    output reg [15:0]  d_uncore_respond_data,

    input              i_uncore_request_valid,
    input      [31:0]  i_uncore_request_addr,
    output             i_uncore_request_busy,
    output reg         i_uncore_respond_valid,
    output reg [15:0]  i_uncore_respond_data,

    // ---------------- SDRAM 引脚 ----------------
    output             sdram_cke,
    output             sdram_cs_n,
    output             sdram_ras_n,
    output             sdram_cas_n,
    output             sdram_we_n,
    output     [1:0]   sdram_ba,
    output     [1:0]   sdram_dm,
    output     [12:0]  sdram_a,
    inout      [15:0]  sdram_dq,

    // ---------------- UART 引脚 ----------------
    output             uart_tx
);

// #region 请求暂存
reg d_pop;
reg i_pop;
// 组合逻辑接口


reg         d_p;
reg         d_p_we;
reg [15:0]  d_p_be;
reg [31:0]  d_p_addr;
reg [127:0] d_p_data;

reg         i_p;
reg [31:0]  i_p_addr;

assign d_uncore_request_busy = d_p;
assign i_uncore_request_busy = i_p;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_p <= 1'h0;
        i_p <= 1'h0;
    end
    else begin
        if (d_pop) begin
            d_p <= 1'h0;
        end
        else if (d_uncore_request_valid && !d_p) begin
            d_p <= 1'h1;
            d_p_we <= d_uncore_request_we;
            d_p_be <= d_uncore_request_be;
            d_p_addr <= d_uncore_request_addr;
            d_p_data <= d_uncore_request_data;
        end
        if (i_pop) begin
            i_p <= 1'h0;
        end
        else if (i_uncore_request_valid && !i_p) begin
            i_p <= 1'h1;
            i_p_addr <= i_uncore_request_addr;
        end
    end
end
// #endregion



// #region 状态机
reg [2:0] nxt_status;
// 组合逻辑接口


localparam SEND   = 3'h0;
localparam D_WAIT = 3'h1;
localparam D_GET  = 3'h2;
localparam I_WAIT = 3'h3;
localparam I_GET  = 3'h4;
reg [2:0] status;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        status <= SEND;
    end
    else begin
        status <= nxt_status;
    end
end
// #endregion


function automatic [1:0] pma;
    input [31:0] paddr;
    begin
        pma = paddr[31:24] != 8'h0 ? 2'h0 :  // 未映射区域
              paddr[23] ? 2'h2 :             // I/D 均不可缓存区域
              paddr[22:10] == 13'h0 ? 2'h3 : // I 可缓存，D 不可缓存区域
              2'h1;                          // I/D 均可缓存区域
    end
endfunction

reg src; // 0: d, 1: i
reg request_valid [3:0];


wire        request_busy  [3:0];
wire        respond_valid [3:0];
wire [15:0] respond_data  [3:0];

boot_rom u_boot_rom (
    .clk          (clk),
    .rst_n        (rst_n),
    .request_valid(request_valid[3]),
    .request_we   (src ? 1'h0 : d_p_we),
    .request_be   (d_p_be),
    .request_addr (src ? i_p_addr : d_p_addr),
    .request_data (d_p_data),
    .request_busy (request_busy[3]),
    .respond_valid(respond_valid[3]),
    .respond_data (respond_data[3])
);

null_device u_null_device (
    .clk          (clk),
    .rst_n        (rst_n),
    .request_valid(request_valid[0]),
    .request_we   (src ? 1'h0 : d_p_we),
    .request_be   (d_p_be),
    .request_addr (src ? i_p_addr : d_p_addr),
    .request_data (d_p_data),
    .request_busy (request_busy[0]),
    .respond_valid(respond_valid[0]),
    .respond_data (respond_data[0])
);

uart_tx_unit #(
    .DIV(SYS_HZ / 115_200)
) u_uart_tx_unit (
    .clk          (clk),
    .rst_n        (rst_n),
    .request_valid(request_valid[2]),
    .request_we   (src ? 1'h0 : d_p_we),
    .request_be   (d_p_be),
    .request_addr (src ? i_p_addr : d_p_addr),
    .request_data (d_p_data),
    .request_busy (request_busy[2]),
    .respond_valid(respond_valid[2]),
    .respond_data (respond_data[2]),
    .tx           (uart_tx)
);

sdram_ctr u_sdram_ctr (
    .clk          (clk),
    .rst_n        (rst_n),
    .request_valid(request_valid[1]),
    .request_we   (src ? 1'h0 : d_p_we),
    .request_be   (d_p_be),
    .request_addr (src ? i_p_addr : d_p_addr),
    .request_data (d_p_data),
    .request_busy (request_busy[1]),
    .respond_valid(respond_valid[1]),
    .respond_data (respond_data[1]),
    .sdram_cke    (sdram_cke),
    .sdram_cs_n   (sdram_cs_n),
    .sdram_ras_n  (sdram_ras_n),
    .sdram_cas_n  (sdram_cas_n),
    .sdram_we_n   (sdram_we_n),
    .sdram_ba     (sdram_ba),
    .sdram_dm     (sdram_dm),
    .sdram_a      (sdram_a),
    .sdram_dq     (sdram_dq)
);

always @(*) begin : comb
    integer i;
    d_uncore_respond_valid = 1'h0;
    d_uncore_respond_data  = 16'h0;
    i_uncore_respond_valid = 1'h0;
    i_uncore_respond_data  = 16'h0;
    d_pop      = 1'h0;
    i_pop      = 1'h0;
    nxt_status = SEND;
    src        = 1'h0;
    for (i = 0; i < 4; i = i + 1) begin
        request_valid[i] = 1'h0;
    end
    case (status)
        SEND: begin
            if (d_p) begin
                if (!request_busy[pma(d_p_addr)]) begin
                    request_valid[pma(d_p_addr)] = 1'h1;
                    src = 1'h0;
                    if (d_p_we) begin
                        nxt_status = SEND;
                        d_pop = 1'h1;
                    end
                    else begin
                        nxt_status = D_WAIT;
                    end
                end
                else begin
                    nxt_status = SEND;
                end
            end
            else if (i_p) begin
                if (!request_busy[pma(i_p_addr)]) begin
                    request_valid[pma(i_p_addr)] = 1'h1;
                    src = 1'h1;
                    nxt_status = I_WAIT;
                end
                else begin
                    nxt_status = SEND;
                end
            end
            else begin
                nxt_status = SEND;
            end
        end
        D_WAIT: begin
            d_uncore_respond_valid = respond_valid[pma(d_p_addr)];
            d_uncore_respond_data = respond_data[pma(d_p_addr)];
            if (respond_valid[pma(d_p_addr)]) begin
                nxt_status = D_GET;
            end
            else begin
                nxt_status = D_WAIT;
            end
        end
        D_GET: begin
            d_uncore_respond_valid = respond_valid[pma(d_p_addr)];
            d_uncore_respond_data = respond_data[pma(d_p_addr)];
            if (!respond_valid[pma(d_p_addr)]) begin
                d_pop = 1'h1;
                nxt_status = SEND;
            end
            else begin
                nxt_status = D_GET;
            end
        end
        I_WAIT: begin
            i_uncore_respond_valid = respond_valid[pma(i_p_addr)];
            i_uncore_respond_data = respond_data[pma(i_p_addr)];
            if (respond_valid[pma(i_p_addr)]) begin
                nxt_status = I_GET;
            end
            else begin
                nxt_status = I_WAIT;
            end
        end
        I_GET: begin
            i_uncore_respond_valid = respond_valid[pma(i_p_addr)];
            i_uncore_respond_data = respond_data[pma(i_p_addr)];
            if (!respond_valid[pma(i_p_addr)]) begin
                i_pop = 1'h1;
                nxt_status = SEND;
            end
            else begin
                nxt_status = I_GET;
            end
        end
        default: ;
    endcase
end

endmodule
