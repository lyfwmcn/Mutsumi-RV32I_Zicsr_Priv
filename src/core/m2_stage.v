`timescale 1ns / 1ns

// 9.6 ns
module m2_stage (
    // 全局参数
    input             clk,
    input             rst_n,
    input             flush,
    input             interrupt_cause_valid,
    input             medeleg_exception_cause,
    input             mideleg_interrupt_cause,
    input             MIE,
    input             MPIE,
    input             SIE,
    input             SPIE,
    input             SPP,
    input      [1:0]  MPP,
    input      [1:0]  privilege,
    input      [3:0]  interrupt_cause,
    input      [31:0] medeleg,
    input      [31:0] mip,
    output            actual_jump,
    output            csr_flush,
    output            mem_res_wait,
    output            next_MIE,
    output            next_MPIE,
    output            next_SIE,
    output            next_SPIE,
    output            ret,
    output            ret_type,
    output            trap,
    output            trap_type,
    output            next_SPP,
    output            wfi_wait,
    output     [1:0]  next_MPP,
    output     [1:0]  nextprivilege,
    output     [31:0] next_mcause,
    output     [31:0] next_mepc,
    output     [31:0] next_mtval,
    output     [31:0] next_scause,
    output     [31:0] next_sepc,
    output     [31:0] next_stval,

    // 外部通信参数
    input             d_cache_respond_access_fault,
    input             d_cache_respond_page_fault,
    input             d_cache_respond_valid,
    input      [31:0] d_cache_respond_data,

    // 流水线参数
    input             m2_actual_jump,
    input             m2_csr_wr,
    input             m2_fstcause_valid,
    input             m2_is_csr,
    input             m2_is_instr,
    input             m2_mem_valid,
    input             m2_reg_wr,
    input             m2_ret,
    input             m2_ret_type,
    input             m2_wfi,
    input      [2:0]  m2_reg_src,
    input      [3:0]  m2_fstcause,
    input      [4:0]  m2_mem_ctr,
    input      [4:0]  m2_rd,
    input      [11:0] m2_csr_rd,
    input      [31:0] m2_alu_out,
    input      [31:0] m2_csr_in,
    input      [31:0] m2_instr,
    input      [31:0] m2_nextpc,
    input      [31:0] m2_pc,
    input      [31:0] m2_raw_reg_in,
    output reg        wb_csr_wr,
    output reg        wb_is_csr,
    output reg        wb_is_instr,
    output reg        wb_reg_wr,
    output reg [2:0]  wb_reg_src,
    output reg [4:0]  wb_rd,
    output reg [11:0] wb_csr_rd,
    output reg [31:0] wb_csr_in,
    output reg [31:0] wb_mem,
    output reg [31:0] wb_raw_reg_in
);

assign actual_jump = m2_actual_jump;
assign csr_flush = m2_is_csr && m2_csr_wr && m2_csr_rd == 12'h180;
assign ret = m2_ret;
assign ret_type = m2_ret_type;
assign wfi_wait = m2_wfi;

reg [31:0] wb_nextpc;

wire [31:0] data8s [3:0];
assign data8s[0] = {{24{d_cache_respond_data[7]}}, d_cache_respond_data[7:0]};
assign data8s[1] = {{24{d_cache_respond_data[15]}}, d_cache_respond_data[15:8]};
assign data8s[2] = {{24{d_cache_respond_data[23]}}, d_cache_respond_data[23:16]};
assign data8s[3] = {{24{d_cache_respond_data[31]}}, d_cache_respond_data[31:24]};

wire [31:0] data16s [1:0];
assign data16s[0] = {{16{d_cache_respond_data[15]}}, d_cache_respond_data[15:0]};
assign data16s[1] = {{16{d_cache_respond_data[31]}}, d_cache_respond_data[31:16]};

wire [31:0] data32;
assign data32 = d_cache_respond_data;

wire [31:0] data8u [3:0];
assign data8u[0] = {24'h0, d_cache_respond_data[7:0]};
assign data8u[1] = {24'h0, d_cache_respond_data[15:8]};
assign data8u[2] = {24'h0, d_cache_respond_data[23:16]};
assign data8u[3] = {24'h0, d_cache_respond_data[31:24]};

wire [31:0] data16u [1:0];
assign data16u[0] = {16'h0, d_cache_respond_data[15:0]};
assign data16u[1] = {16'h0, d_cache_respond_data[31:16]};

wire [31:0] m2_mem;
assign m2_mem = !d_cache_respond_valid || d_cache_respond_access_fault || d_cache_respond_page_fault ? 32'h0 :
                m2_mem_ctr[2:0] == 3'h0 ? data8s[m2_alu_out[1:0]] :
                m2_mem_ctr[2:0] == 3'h1 ? data16s[m2_alu_out[1]] :
                m2_mem_ctr[2:0] == 3'h2 ? data32 :
                m2_mem_ctr[2:0] == 3'h4 ? data8u[m2_alu_out[1:0]] :
                data16u[m2_alu_out[1]];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // wb_csr_wr <= 1'h0;
        wb_is_csr <= 1'h0;
        wb_is_instr <= 1'h0;
        wb_reg_wr <= 1'h0;
        // wb_reg_src <= 3'h0;
        // wb_rd <= 5'h0;
        // wb_csr_rd <= 12'h0;
        // wb_csr_in <= 32'h0;
        // wb_mem <= 32'h0;
        // wb_next_pc <= 32'h0;
        // wb_raw_reg_in <= 32'h0;
    end
    else if (flush) begin
        // wb_csr_wr <= 1'h0;
        wb_is_csr <= 1'h0;
        wb_is_instr <= 1'h0;
        wb_reg_wr <= 1'h0;
        // wb_reg_src <= 3'h0;
        // wb_rd <= 5'h0;
        // wb_csr_rd <= 12'h0;
        // wb_csr_in <= 32'h0;
        // wb_mem <= 32'h0;
        // wb_next_pc <= 32'h0;
        // wb_raw_reg_in <= 32'h0;
    end
    else begin
        wb_csr_wr <= m2_csr_wr;
        wb_is_csr <= m2_is_csr;
        wb_is_instr <= m2_is_instr;
        wb_reg_wr <= m2_reg_wr;
        wb_reg_src <= m2_reg_src;
        wb_rd <= m2_rd;
        wb_csr_rd <= m2_csr_rd;
        wb_csr_in <= m2_csr_in;
        wb_mem <= m2_mem;
        wb_nextpc <= !m2_is_instr ? wb_nextpc :
                     m2_nextpc;
        wb_raw_reg_in <= m2_raw_reg_in;
    end
end

// sfence/fence.i 也要等 cache 的响应（可能要几十拍）
assign mem_res_wait = m2_mem_valid && !d_cache_respond_valid;

wire m2_load_access_fault = m2_mem_valid && m2_mem_ctr[4:3] == 2'h0 && d_cache_respond_valid && d_cache_respond_access_fault;
wire m2_load_page_fault = m2_mem_valid && m2_mem_ctr[4:3] == 2'h0 && d_cache_respond_valid && d_cache_respond_page_fault;
wire m2_store_access_fault = m2_mem_valid && m2_mem_ctr[4:3] == 2'h1 && d_cache_respond_valid && d_cache_respond_access_fault;
wire m2_store_page_fault = m2_mem_valid && m2_mem_ctr[4:3] == 2'h1 && d_cache_respond_valid && d_cache_respond_page_fault;

trap_unit trap_unit (
    .interrupt_cause_valid  (interrupt_cause_valid),
    .m2_fstcause_valid      (m2_fstcause_valid),
    .m2_load_access_fault   (m2_load_access_fault),
    .m2_load_page_fault     (m2_load_page_fault),
    .m2_store_access_fault  (m2_store_access_fault),
    .m2_store_page_fault    (m2_store_page_fault),
    .medeleg_exception_cause(medeleg_exception_cause),
    .mideleg_interrupt_cause(mideleg_interrupt_cause),
    .MIE                    (MIE),
    .MPIE                   (MPIE),
    .ret_type               (ret_type),
    .SIE                    (SIE),
    .SPIE                   (SPIE),
    .SPP                    (SPP),
    .MPP                    (MPP),
    .privilege              (privilege),
    .interrupt_cause        (interrupt_cause),
    .m2_fstcause            (m2_fstcause),
    .m2_alu_out             (m2_alu_out),
    .m2_instr               (m2_instr),
    .m2_pc                  (m2_pc),
    .m2_nextpc              (m2_nextpc),
    .medeleg                (medeleg),
    .mip                    (mip),
    .wb_nextpc              (wb_nextpc),
    .next_MIE               (next_MIE),
    .next_MPIE              (next_MPIE),
    .next_SIE               (next_SIE),
    .next_SPIE              (next_SPIE),
    .trap                   (trap),
    .trap_type              (trap_type),
    .next_MPP               (next_MPP),
    .next_SPP               (next_SPP),
    .nextprivilege          (nextprivilege),
    .next_mcause            (next_mcause),
    .next_mepc              (next_mepc),
    .next_mtval             (next_mtval),
    .next_scause            (next_scause),
    .next_sepc              (next_sepc),
    .next_stval             (next_stval)
);

endmodule
