`timescale 1ns / 1ns

module m1_stage (
    // 全局变量
    input             clk,
    input             flush,
    input             stall,
    input      [1:0]  privilege,
    input      [31:0] mepc,
    input      [31:0] sepc,
    output            request_valid_data,
    output            request_write_data,
    output     [3:0]  request_en_data,
    output     [31:0] request_addr_data,
    output     [31:0] request_data_data,

    // 流水线参数
    input             m1_zf,
    input             m1_cf,
    input             m1_sf,
    input             m1_of,
    input             m1_csr_wr,
    input             m1_data_ren,
    input             m1_data_wen,
    input             m1_ebreak,
    input             m1_ecall,
    input             m1_instr_access_fault,
    input             m1_instr_illegal_fault,
    input             m1_instr_page_fault,
    input             m1_is_csr,
    input             m1_is_instr,
    input             m1_predtaken,
    input             m1_reg_wr,
    input             m1_ret,
    input             m1_ret_type,
    input      [2:0]  m1_mem_ctr,
    input      [2:0]  m1_reg_src,
    input      [4:0]  m1_branch_ctr,
    input      [4:0]  m1_rd,
    input      [11:0] m1_csr_rd,
    input      [31:0] m1_alu_out,
    input      [31:0] m1_csr_out,
    input      [31:0] m1_imm,
    input      [31:0] m1_instr,
    input      [31:0] m1_pc,
    input      [31:0] m1_pcplus4,
    input      [31:0] m1_pcplusimm,
    input      [31:0] m1_raw_csr_in,
    input      [31:0] m1_raw_reg_in,
    input      [31:0] m1_reg_out_b,
    output reg        m2_actual_jump,
    output reg        m2_csr_wr,
    output reg        m2_data_ren,
    output reg        m2_data_wen,
    output reg        m2_is_csr,
    output reg        m2_is_instr,
    output reg        m2_reg_wr,
    output reg        m2_ret,
    output reg        m2_ret_type,
    output reg        m2_fstcause_valid,
    output reg [2:0]  m2_mem_ctr,
    output reg [2:0]  m2_reg_src,
    output reg [3:0]  m2_fstcause,
    output reg [4:0]  m2_rd,
    output reg [11:0] m2_csr_rd,
    output reg [31:0] m2_alu_out,
    output reg [31:0] m2_csr_in,
    output reg [31:0] m2_csr_out,
    output reg [31:0] m2_imm,
    output reg [31:0] m2_instr,
    output reg [31:0] m2_jump_addr,
    output reg [31:0] m2_nextpc,
    output reg [31:0] m2_pc,
    output reg [31:0] m2_pcplus4,
    output reg [31:0] m2_pcplusimm,
    output reg [31:0] m2_raw_reg_in
);

wire m1_load_align_fault;
wire m1_store_align_fault;
wire m1_instr_align_fault;
wire m1_actual_jump;
wire [31:0] m1_jump_addr;
wire [31:0] m1_nextpc;
wire [31:0] m1_csr_in;

assign m1_load_align_fault = m1_data_ren == 1'h1 && (((m1_mem_ctr == 3'h1 || m1_mem_ctr == 3'h5) && m1_alu_out[0] != 1'h0) || (m1_mem_ctr == 3'h2 && m1_alu_out[1:0] != 2'h0));
assign m1_store_align_fault = m1_data_wen == 1'h1 && ((m1_mem_ctr == 3'h1 && m1_alu_out[0] != 1'h0) || (m1_mem_ctr == 3'h2 && m1_alu_out[1:0] != 2'h0));
assign m1_instr_align_fault = m1_nextpc[1:0] != 2'h0;

assign request_valid_data = !flush && !stall && ((m1_data_ren && !m1_load_align_fault) || (m1_data_wen && !m1_store_align_fault));
assign request_write_data = m1_data_wen;
wire [3:0] m_en0 [3:0];
assign m_en0[0] = 4'h1;
assign m_en0[1] = 4'h2;
assign m_en0[2] = 4'h4;
assign m_en0[3] = 4'h8;
wire [3:0] m_en1 [1:0];
assign m_en1[0] = 4'h3;
assign m_en1[1] = 4'hc;
wire [3:0] m_en2;
assign m_en2 = 4'hf;
assign request_en_data = m1_mem_ctr[1:0] == 2'h0 ? m_en0[m1_alu_out[1:0]] :
                         m1_mem_ctr[1:0] == 2'h1 ? m_en1[m1_alu_out[1]] :
                         m1_mem_ctr[1:0] == 2'h2 ? m_en2 :
                         4'h0;
assign request_addr_data = {m1_alu_out[31:2], 2'h0};
wire [31:0] m_data0 [3:0];
assign m_data0[0] = {24'h0, m1_reg_out_b[7:0]};
assign m_data0[1] = {16'h0, m1_reg_out_b[7:0], 8'h0};
assign m_data0[2] = {8'h0, m1_reg_out_b[7:0], 16'h0};
assign m_data0[3] = {m1_reg_out_b[7:0], 24'h0};
wire [31:0] m_data1 [1:0];
assign m_data1[0] = {16'h0, m1_reg_out_b[15:0]};
assign m_data1[1] = {m1_reg_out_b[15:0], 16'h0};
wire [31:0] m_data2;
assign m_data2 = m1_reg_out_b;
assign request_data_data = !m1_data_wen ? 32'h0 :
                           m1_mem_ctr == 3'h0 ? m_data0[m1_alu_out[1:0]] :
                           m1_mem_ctr == 3'h1 ? m_data1[m1_alu_out[1]] :
                           m1_mem_ctr == 3'h2 ? m_data2 :
                           32'h0;

wire [3:0] m1_fstcause;
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

initial begin
    m2_actual_jump = 1'h0;
    m2_csr_wr = 1'h0;
    m2_data_ren = 1'h0;
    m2_data_wen = 1'h0;
    m2_is_csr = 1'h0;
    m2_is_instr = 1'h0;
    m2_reg_wr = 1'h1;
    m2_ret = 1'h0;
    m2_ret_type = 1'h0;
    m2_fstcause_valid = 1'h0;
    m2_mem_ctr = 3'h0;
    m2_reg_src = 3'h0;
    m2_fstcause = 4'h0;
    m2_rd = 5'h0;
    m2_csr_rd = 12'h0;
    m2_alu_out = 32'h0;
    m2_csr_in = 32'h0;
    m2_csr_out = 32'h0;
    m2_imm = 32'h0;
    m2_instr = 32'h13;
    m2_jump_addr = 32'h0;
    m2_nextpc = 32'h4;
    m2_pc = 32'h0;
    m2_pcplus4 = 32'h4;
    m2_pcplusimm = 32'h0;
    m2_raw_reg_in = 32'h0;
end

always @(posedge clk) begin
    if (flush) begin
        m2_actual_jump <= 1'h0;
        m2_csr_wr <= 1'h0;
        m2_data_ren <= 1'h0;
        m2_data_wen <= 1'h0;
        m2_is_csr <= 1'h0;
        m2_is_instr <= 1'h0;
        m2_reg_wr <= 1'h1;
        m2_ret <= 1'h0;
        m2_ret_type <= 1'h0;
        m2_fstcause_valid <= 1'h0;
        m2_mem_ctr <= 3'h0;
        m2_reg_src <= 3'h0;
        m2_fstcause <= 4'h0;
        m2_rd <= 5'h0;
        m2_csr_rd <= 12'h0;
        m2_alu_out <= 32'h0;
        m2_csr_in <= 32'h0;
        m2_csr_out <= 32'h0;
        m2_imm <= 32'h0;
        m2_instr <= 32'h13;
        m2_jump_addr <= 32'h0;
        m2_nextpc <= 32'h4;
        m2_pc <= 32'h0;
        m2_pcplus4 <= 32'h4;
        m2_pcplusimm <= 32'h0;
        m2_raw_reg_in <= 32'h0;
    end
    else if (!stall) begin
        m2_actual_jump <= m1_actual_jump;
        m2_csr_wr <= m1_csr_wr;
        m2_data_ren <= m1_data_ren;
        m2_data_wen <= m1_data_wen;
        m2_is_csr <= m1_is_csr;
        m2_is_instr <= m1_is_instr;
        m2_reg_wr <= m1_reg_wr;
        m2_ret <= m1_ret;
        m2_ret_type <= m1_ret_type;
        m2_fstcause_valid <= m1_fstcause_valid;
        m2_mem_ctr <= m1_mem_ctr;
        m2_reg_src <= m1_reg_src;
        m2_fstcause <= m1_fstcause;
        m2_rd <= m1_rd;
        m2_csr_rd <= m1_csr_rd;
        m2_alu_out <= m1_alu_out;
        m2_csr_in <= m1_csr_in;
        m2_csr_out <= m1_csr_out;
        m2_imm <= m1_imm;
        m2_instr <= m1_instr;
        m2_jump_addr <= m1_jump_addr;
        m2_nextpc <= m1_nextpc;
        m2_pc <= m1_pc;
        m2_pcplus4 <= m1_pcplus4;
        m2_pcplusimm <= m1_pcplusimm;
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
    .raw_csr_in(m1_raw_csr_in),
    .csr_in    (m1_csr_in)
);

endmodule
