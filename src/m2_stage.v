`timescale 1ns / 1ns

// 9.6 ns
module m2_stage (
    // 全局参数
    input             clk,
    input             flush,
    input             MIE,
    input             MPIE,
    input             SIE,
    input             SPIE,
    input             SPP,
    input      [1:0]  MPP,
    input      [1:0]  privilege,
    input      [31:0] medeleg,
    input      [31:0] mideleg,
    input      [31:0] mie,
    input      [31:0] mip,
    output            actual_jump,
    output            mem_wait,
    output            next_MIE,
    output            next_MPIE,
    output            next_SIE,
    output            next_SPIE,
    output            ret,
    output            ret_type,
    output            trap,
    output            trap_type,
    output            next_SPP,
    output     [1:0]  next_MPP,
    output     [1:0]  nextprivilege,
    output     [31:0] next_mcause,
    output     [31:0] next_mepc,
    output     [31:0] next_mtval,
    output     [31:0] next_scause,
    output     [31:0] next_sepc,
    output     [31:0] next_stval,

    // 外部通信参数
    input             respond_fault_data,
    input             respond_valid_data,
    input      [31:0] respond_data_data,

    // 流水线参数
    input             m2_actual_jump,
    input             m2_csr_wr,
    input             m2_data_ren,
    input             m2_data_wen,
    input             m2_is_csr,
    input             m2_is_instr,
    input             m2_reg_wr,
    input             m2_ret,
    input             m2_ret_type,
    input             m2_fstcause_valid,
    input      [2:0]  m2_mem_ctr,
    input      [2:0]  m2_reg_src,
    input      [3:0]  m2_fstcause,
    input      [4:0]  m2_rd,
    input      [11:0] m2_csr_rd,
    input      [31:0] m2_alu_out,
    input      [31:0] m2_csr_in,
    input      [31:0] m2_csr_out,
    input      [31:0] m2_imm,
    input      [31:0] m2_instr,
    input      [31:0] m2_nextpc,
    input      [31:0] m2_pc,
    input      [31:0] m2_pcplus4,
    input      [31:0] m2_pcplusimm,
    input      [31:0] m2_raw_reg_in,
    output reg        wb_csr_wr,
    output reg        wb_is_csr,
    output reg        wb_is_instr,
    output reg        wb_reg_wr,
    output reg [2:0]  wb_reg_src,
    output reg [4:0]  wb_rd,
    output reg [11:0] wb_csr_rd,
    output reg [31:0] wb_alu_out,
    output reg [31:0] wb_csr_in,
    output reg [31:0] wb_csr_out,
    output reg [31:0] wb_imm,
    output reg [31:0] wb_mem,
    output reg [31:0] wb_pcplus4,
    output reg [31:0] wb_pcplusimm
);

assign actual_jump = m2_actual_jump;

reg [31:0] wb_nextpc;

initial begin
    wb_csr_wr = 1'h0;
    wb_is_csr = 1'h0;
    wb_is_instr = 1'h0;
    wb_reg_wr = 1'h0;
    wb_reg_src = 3'h0;
    wb_rd = 5'h0;
    wb_csr_rd = 12'h0;
    wb_alu_out = 32'h0;
    wb_csr_in = 32'h0;
    wb_csr_out = 32'h0;
    wb_imm = 32'h0;
    wb_mem = 32'h0;
    wb_nextpc = 32'h0;
    wb_pcplus4 = 32'h0;
    wb_pcplusimm = 32'h0;
end

always @(posedge clk) begin
    if (flush) begin
        wb_csr_wr <= 1'h0;
        wb_is_csr <= 1'h0;
        wb_is_instr <= 1'h0;
        wb_reg_wr <= 1'h0;
        wb_reg_src <= 3'h0;
        wb_rd <= 5'h0;
        wb_csr_rd <= 12'h0;
        wb_alu_out <= 32'h0;
        wb_csr_in <= 32'h0;
        wb_csr_out <= 32'h0;
        wb_imm <= 32'h0;
        wb_mem <= 32'h0;
        wb_nextpc <= 32'h0;
        wb_pcplus4 <= 32'h0;
        wb_pcplusimm <= 32'h0;
    end
    else begin
        wb_csr_wr <= m2_csr_wr;
        wb_is_csr <= m2_is_csr;
        wb_is_instr <= m2_is_instr;
        wb_reg_wr <= m2_reg_wr;
        wb_reg_src <= m2_reg_src;
        wb_rd <= m2_rd;
        wb_csr_rd <= m2_csr_rd;
        wb_alu_out <= m2_alu_out;
        wb_csr_in <= m2_csr_in;
        wb_csr_out <= m2_csr_out;
        wb_imm <= m2_imm;
        wb_mem <= m2_mem;
        wb_nextpc <= !m2_is_instr ? wb_nextpc :
                     m2_nextpc;
        wb_pcplus4 <= m2_pcplus4;
        wb_pcplusimm <= m2_pcplusimm;
    end
end

assign ret = m2_ret;
assign ret_type = m2_ret_type;
assign mem_wait = (m2_data_ren || m2_data_wen) && !respond_valid_data;

wire [31:0] Data8S [3:0];
assign Data8S[0] = {{24{respond_data_data[7]}}, respond_data_data[7:0]};
assign Data8S[1] = {{24{respond_data_data[15]}}, respond_data_data[15:8]};
assign Data8S[2] = {{24{respond_data_data[23]}}, respond_data_data[23:16]};
assign Data8S[3] = {{24{respond_data_data[31]}}, respond_data_data[31:24]};

wire [31:0] Data16S [1:0];
assign Data16S[0] = {{16{respond_data_data[15]}}, respond_data_data[15:0]};
assign Data16S[1] = {{16{respond_data_data[31]}}, respond_data_data[31:16]};

wire [31:0] Data32;
assign Data32 = respond_data_data;

wire [31:0] Data8U [3:0];
assign Data8U[0] = {24'h0, respond_data_data[7:0]};
assign Data8U[1] = {24'h0, respond_data_data[15:8]};
assign Data8U[2] = {24'h0, respond_data_data[23:16]};
assign Data8U[3] = {24'h0, respond_data_data[31:24]};

wire [31:0] Data16U [1:0];
assign Data16U[0] = {16'h0, respond_data_data[15:0]};
assign Data16U[1] = {16'h0, respond_data_data[31:16]};

wire [31:0] m2_mem;
assign m2_mem = !respond_valid_data || respond_fault_data ? 32'h0 :
               m2_mem_ctr == 3'h0 ? Data8S[m2_alu_out[1:0]] :
               m2_mem_ctr == 3'h1 ? Data16S[m2_alu_out[1]] :
               m2_mem_ctr == 3'h2 ? Data32 :
               m2_mem_ctr == 3'h4 ? Data8U[m2_alu_out[1:0]] :
               m2_mem_ctr == 3'h5 ? Data16U[m2_alu_out[1]] :
               32'h0;

wire m2_load_access_fault;
wire m2_load_page_fault;
wire m2_store_access_fault;
wire m2_store_page_fault;

assign m2_load_access_fault = m2_data_ren && respond_valid_data && respond_fault_data;
assign m2_store_access_fault = m2_data_wen && respond_valid_data && respond_fault_data;
assign m2_load_page_fault = 1'h0;
assign m2_store_page_fault = 1'h0;

trap_unit trap_unit (
    .m2_fstcause_valid     (m2_fstcause_valid),
    .m2_load_access_fault  (m2_load_access_fault),
    .m2_load_page_fault    (m2_load_page_fault),
    .m2_store_access_fault (m2_store_access_fault),
    .m2_store_page_fault   (m2_store_page_fault),
    .MIE                   (MIE),
    .MPIE                  (MPIE),
    .ret                   (ret),
    .ret_type              (ret_type),
    .SIE                   (SIE),
    .SPIE                  (SPIE),
    .SPP                   (SPP),
    .MPP                   (MPP),
    .privilege             (privilege),
    .m2_fstcause           (m2_fstcause),
    .m2_alu_out            (m2_alu_out),
    .m2_instr              (m2_instr),
    .m2_pc                 (m2_pc),
    .m2_pcplusimm          (m2_pcplusimm),
    .medeleg               (medeleg),
    .mideleg               (mideleg),
    .mie                   (mie),
    .mip                   (mip),
    .wb_nextpc             (wb_nextpc),
    .next_MIE              (next_MIE),
    .next_MPIE             (next_MPIE),
    .next_SIE              (next_SIE),
    .next_SPIE             (next_SPIE),
    .trap                  (trap),
    .trap_type             (trap_type),
    .next_MPP              (next_MPP),
    .next_SPP              (next_SPP),
    .nextprivilege         (nextprivilege),
    .next_mcause           (next_mcause),
    .next_mepc             (next_mepc),
    .next_mtval            (next_mtval),
    .next_scause           (next_scause),
    .next_sepc             (next_sepc),
    .next_stval            (next_stval)
);

endmodule
