`timescale 1ns / 1ns

module m1_stage (
    // 全局变量
    input             clk,
    input             rst_n,
    input             flush,
    input             stall,
    input             d_cache_request_busy,
    input      [1:0]  privilege,
    input      [31:0] mepc,
    input      [31:0] sepc,
    output            d_cache_request_valid,
    output            mem_req_wait,
    // 0: R  1: W  2: sfence.vma  3: fence.i
    output     [1:0]  d_cache_request_op,
    output     [3:0]  d_cache_request_be,
    output     [29:0] d_cache_request_vaddr, // 高 30 位虚拟地址
    output     [31:0] d_cache_request_data,

    output     [3:0]  m1_fstcause,

    // 流水线参数
    input             m1_zf,
    input             m1_cf,
    input             m1_sf,
    input             m1_of,
    input             m1_csr_wr,
    input             m1_ebreak,
    input             m1_ecall,
    input             m1_instr_access_fault,
    input             m1_instr_illegal_fault,
    input             m1_instr_page_fault,
    input             m1_is_csr,
    input             m1_is_instr,
    input             m1_mem_valid,
    input             m1_predtaken,
    input             m1_reg_wr,
    input             m1_ret,
    input             m1_ret_type,
    input             m1_wfi,
    input      [2:0]  m1_reg_src,
    input      [4:0]  m1_branch_ctr,
    input      [4:0]  m1_mem_ctr,
    input      [4:0]  m1_rd,
    input      [11:0] m1_csr_rd,
    input      [31:0] m1_alu_out,
    input      [31:0] m1_instr,
    input      [31:0] m1_pc,
    input      [31:0] m1_pcplus4,
    input      [31:0] m1_pcplusimm,
    input      [31:0] m1_raw_reg_in,
    input      [31:0] m1_reg_out_b,
    output reg        m2_actual_jump,
    output reg        m2_csr_wr,
    output reg        m2_fstcause_valid,
    output reg        m2_is_csr,
    output reg        m2_is_instr,
    output reg        m2_mem_valid,
    output reg        m2_reg_wr,
    output reg        m2_ret,
    output reg        m2_ret_type,
    output reg        m2_wfi,
    output reg [2:0]  m2_reg_src,
    output reg [3:0]  m2_fstcause,
    output reg [4:0]  m2_mem_ctr,
    output reg [4:0]  m2_rd,
    output reg [11:0] m2_csr_rd,
    output reg [31:0] m2_alu_out,
    output reg [31:0] m2_csr_in,
    output reg [31:0] m2_instr,
    output reg [31:0] m2_jump_addr,
    output reg [31:0] m2_nextpc,
    output reg [31:0] m2_pc,
    output reg [31:0] m2_raw_reg_in
);

wire m1_load_align_fault = m1_mem_valid && m1_mem_ctr[4:3] == 2'h0 &&
                           (((m1_mem_ctr[2:0] == 3'h1 || m1_mem_ctr[2:0] == 3'h5) && m1_alu_out[0] != 1'h0) ||
                           (m1_mem_ctr[2:0] == 3'h2 && m1_alu_out[1:0] != 2'h0));
wire m1_store_align_fault = m1_mem_valid && m1_mem_ctr[4:3] == 2'h1 &&
                            ((m1_mem_ctr[2:0] == 3'h1 && m1_alu_out[0] != 1'h0) ||
                            (m1_mem_ctr[2:0] == 3'h2 && m1_alu_out[1:0] != 2'h0));

wire [31:0] m1_nextpc;

wire m1_instr_align_fault = m1_nextpc[1:0] != 2'h0;

wire m1_actual_jump;
wire [31:0] m1_jump_addr;
wire [31:0] m1_csr_in;

assign mem_req_wait = m1_mem_valid && !m1_load_align_fault && !m1_store_align_fault && d_cache_request_busy;
assign d_cache_request_valid = m1_mem_valid && !flush && !stall && !m1_load_align_fault && !m1_store_align_fault && !d_cache_request_busy;
assign d_cache_request_op = m1_mem_ctr[4:3];
assign d_cache_request_be = m1_mem_ctr[1:0] == 2'h0 ? (m1_alu_out[1:0] == 2'h0 ? 4'h1 :
                                                       m1_alu_out[1:0] == 2'h1 ? 4'h2 :
                                                       m1_alu_out[1:0] == 2'h2 ? 4'h4 :
                                                       4'h8) :
                            m1_mem_ctr[1:0] == 2'h1 ? (m1_alu_out[1] == 1'h0 ? 4'h3 :
                                                       4'hc) :
                            4'hf;
assign d_cache_request_vaddr = m1_alu_out[31:2];
wire [31:0] data8 [3:0];
assign data8[0] = {24'h0, m1_reg_out_b[7:0]};
assign data8[1] = {16'h0, m1_reg_out_b[7:0], 8'h0};
assign data8[2] = {8'h0, m1_reg_out_b[7:0], 16'h0};
assign data8[3] = {m1_reg_out_b[7:0], 24'h0};
wire [31:0] data16 [1:0];
assign data16[0] = {16'h0, m1_reg_out_b[15:0]};
assign data16[1] = {m1_reg_out_b[15:0], 16'h0};
assign d_cache_request_data = m1_mem_ctr[1:0] == 2'h0 ? data8[m1_alu_out[1:0]] :
                              m1_mem_ctr[1:0] == 2'h1 ? data16[m1_alu_out[1]] :
                              m1_reg_out_b;


assign m1_fstcause = m1_instr_page_fault ? 4'hc :
                     m1_instr_access_fault ? 4'h1 :
                     m1_instr_illegal_fault ? 4'h2 :
                     m1_ebreak ? 4'h3 :
                     m1_ecall ? (privilege == 2'h0 ? 4'h8 : privilege == 2'h1 ? 4'h9 : 4'hb) :
                     m1_instr_align_fault ? 4'h0 :
                     m1_load_align_fault ? 4'h4 :
                     m1_store_align_fault ? 4'h6 :
                     4'ha;

wire m1_fstcause_valid;
assign m1_fstcause_valid = m1_instr_page_fault || m1_instr_access_fault || m1_instr_illegal_fault || m1_ebreak || m1_ecall || m1_instr_align_fault || m1_load_align_fault || m1_store_align_fault;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m2_actual_jump <= 1'h0;
        // m2_csr_wr <= 1'h0;
        m2_fstcause_valid <= 1'h0;
        m2_is_csr <= 1'h0;
        m2_is_instr <= 1'h0;
        m2_mem_valid <= 1'h0;
        m2_reg_wr <= 1'h0;
        m2_ret <= 1'h0;
        // m2_ret_type <= 1'h0;
        m2_wfi <= 1'h0;
        // m2_reg_src <= 3'h0;
        // m2_fstcause <= 4'h0;
        // m2_mem_ctr <= 5'h0;
        // m2_rd <= 5'h0;
        // m2_csr_rd <= 12'h0;
        // m2_alu_out <= 32'h0;
        // m2_csr_in <= 32'h0;
        // m2_instr <= 32'h0;
        // m2_jump_addr <= 32'h0;
        // m2_nextpc <= 32'h0;
        // m2_pc <= 32'h0;
        // m2_raw_reg_in <= 32'h0;
    end
    else if (flush) begin
        m2_actual_jump <= 1'h0;
        // m2_csr_wr <= 1'h0;
        m2_fstcause_valid <= 1'h0;
        m2_is_csr <= 1'h0;
        m2_is_instr <= 1'h0;
        m2_mem_valid <= 1'h0;
        m2_reg_wr <= 1'h0;
        m2_ret <= 1'h0;
        // m2_ret_type <= 1'h0;
        m2_wfi <= 1'h0;
        // m2_reg_src <= 3'h0;
        // m2_fstcause <= 4'h0;
        // m2_mem_ctr <= 5'h0;
        // m2_rd <= 5'h0;
        // m2_csr_rd <= 12'h0;
        // m2_alu_out <= 32'h0;
        // m2_csr_in <= 32'h0;
        // m2_instr <= 32'h0;
        // m2_jump_addr <= 32'h0;
        // m2_nextpc <= 32'h0;
        // m2_pc <= 32'h0;
        // m2_raw_reg_in <= 32'h0;
    end
    else if (!stall) begin
        m2_actual_jump <= m1_actual_jump;
        m2_csr_wr <= m1_csr_wr;
        m2_fstcause_valid <= m1_fstcause_valid;
        m2_is_csr <= m1_is_csr;
        m2_is_instr <= m1_is_instr;
        m2_mem_valid <= m1_mem_valid;
        m2_reg_wr <= m1_reg_wr;
        m2_ret <= m1_ret;
        m2_ret_type <= m1_ret_type;
        m2_wfi <= m1_wfi;
        m2_reg_src <= m1_reg_src;
        m2_fstcause <= m1_fstcause;
        m2_mem_ctr <= m1_mem_ctr;
        m2_rd <= m1_rd;
        m2_csr_rd <= m1_csr_rd;
        m2_alu_out <= m1_alu_out;
        m2_csr_in <= m1_csr_in;
        m2_instr <= m1_instr;
        m2_jump_addr <= m1_jump_addr;
        m2_nextpc <= m1_nextpc;
        m2_pc <= m1_pc;
        m2_raw_reg_in <= m1_raw_reg_in;
    end
end

bu bu (
    .zf         (m1_zf),
    .cf         (m1_cf),
    .sf         (m1_sf),
    .of         (m1_of),
    .predtaken  (m1_predtaken),
    .ret        (m1_ret),
    .ret_type   (m1_ret_type),
    .branch_ctr (m1_branch_ctr),
    .alu_out    (m1_alu_out),
    .mepc       (mepc),
    .pcplus4    (m1_pcplus4),
    .pcplusimm  (m1_pcplusimm),
    .sepc       (sepc),
    .actual_jump(m1_actual_jump),
    .jump_addr  (m1_jump_addr),
    .nextpc     (m1_nextpc)
);

csr_read csr_read (
    .csr_rd    (m1_csr_rd),
    .raw_csr_in(m1_alu_out),
    .csr_in    (m1_csr_in)
);

endmodule
