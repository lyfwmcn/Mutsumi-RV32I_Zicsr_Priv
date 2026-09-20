`timescale 1ns / 1ns

module cpu (
    input         clk,
    input         rst_n,

    input         external_interrupt_clear,
    input         external_interrupt_set,
    input         timer_interrupt_clear,
    input         timer_interrupt_set,

    input         respond_fault_data,
    input         respond_fault_instr,
    input         respond_valid_data,
    input         respond_valid_instr,
    input  [31:0] respond_data_data,
    input  [31:0] respond_data_instr,
    output        request_valid_data,
    output        request_valid_instr,
    output        request_write_data,
    output [3:0]  request_en_data,
    output [31:0] request_addr_data,
    output [31:0] request_addr_instr,
    output [31:0] request_data_data
);

wire actual_jump;
wire csr_wait; //* 有延迟
wire mem_wait; //* 有延迟
wire predtaken;
wire reg_wait; //* 有延迟
wire ret;
wire ret_type;
wire trap;
wire trap_type;
wire [1:0] privilege;

wire        cur_MIE;
wire        cur_MPIE;
wire        cur_SIE;
wire        cur_SPIE;
wire        cur_SPP;
wire [1:0]  cur_MPP;
wire [31:0] cur_medeleg;
wire [31:0] cur_mepc;
wire [31:0] cur_mideleg;
wire [31:0] cur_mie;
wire [31:0] cur_mip;
wire [31:0] cur_mtvec;
wire [31:0] cur_sepc;
wire [31:0] cur_stvec;

wire        interrupt_cause_valid;
wire        medeleg_exception_cause;
wire        mideleg_interrupt_cause;
wire        MIE;
wire        MPIE;
wire        SIE;
wire        SPIE;
wire        SPP;
wire [1:0]  MPP;
wire [3:0]  interrupt_cause;
wire [31:0] medeleg;
wire [31:0] mepc;
wire [31:0] mideleg;
wire [31:0] mie;
wire [31:0] mip;
wire [31:0] mtvec;
wire [31:0] sepc;
wire [31:0] stvec;

wire        id_instr_access_fault;
wire        id_instr_page_fault;
wire        id_is_instr;
wire [31:0] id_instr;
wire [31:0] id_pc;
wire [31:0] id_pcplus4;

wire [31:0] id_jump_addr; //* 有延迟

wire        ex1_alu_src_a;
wire        ex1_csr_wr;
wire        ex1_data_ren;
wire        ex1_data_wen;
wire        ex1_ebreak;
wire        ex1_ecall;
wire        ex1_instr_access_fault;
wire        ex1_instr_illegal_fault;
wire        ex1_instr_page_fault;
wire        ex1_is_csr;
wire        ex1_is_instr;
wire        ex1_predtaken;
wire        ex1_reg_out_a_used;
wire        ex1_reg_out_b_used;
wire        ex1_reg_wr;
wire        ex1_ret;
wire        ex1_ret_type;
wire [1:0]  ex1_alu_src_b;
wire [1:0]  ex1_csr_src;
wire [2:0]  ex1_mem_ctr;
wire [2:0]  ex1_reg_src;
wire [4:0]  ex1_branch_ctr;
wire [4:0]  ex1_rd;
wire [4:0]  ex1_rs1;
wire [4:0]  ex1_rs2;
wire [5:0]  ex1_alu_ctr;
wire [11:0] ex1_csr_rd;
wire [31:0] ex1_csr_out;   // 有延迟
wire [31:0] ex1_imm;
wire [31:0] ex1_instr;
wire [31:0] ex1_pc;
wire [31:0] ex1_pcplus4;
wire [31:0] ex1_pcplusimm;
wire [31:0] ex1_reg_out_a; // 有延迟
wire [31:0] ex1_reg_out_b; // 有延迟

wire        ex2_aluinausem1;
wire        ex2_aluinbusem1;
wire        ex2_csr_wr;
wire        ex2_data_ren;
wire        ex2_data_wen;
wire        ex2_ebreak;
wire        ex2_ecall;
wire        ex2_instr_access_fault;
wire        ex2_instr_illegal_fault;
wire        ex2_instr_page_fault;
wire        ex2_is_csr;
wire        ex2_is_instr;
wire        ex2_predtaken;
wire        ex2_reg_wr;
wire        ex2_ret;
wire        ex2_ret_type;
wire        ex2_rs1usem1;
wire        ex2_rs2usem1;
wire [1:0]  ex2_csr_src;
wire [2:0]  ex2_mem_ctr;
wire [2:0]  ex2_reg_src;
wire [4:0]  ex2_branch_ctr;
wire [4:0]  ex2_rd;
wire [5:0]  ex2_alu_ctr;
wire [11:0] ex2_csr_rd;
wire [31:0] ex2_alu_in_a;
wire [31:0] ex2_alu_in_b;
wire [31:0] ex2_csr_out;
wire [31:0] ex2_imm;
wire [31:0] ex2_instr;
wire [31:0] ex2_pc;
wire [31:0] ex2_pcplus4;
wire [31:0] ex2_pcplusimm;
wire [31:0] ex2_reg_out_a;
wire [31:0] ex2_reg_out_b;

wire        m1_zf;
wire        m1_cf;
wire        m1_sf;
wire        m1_of;
wire        m1_csr_wr;
wire        m1_data_ren;
wire        m1_data_wen;
wire        m1_ebreak;
wire        m1_ecall;
wire        m1_instr_access_fault;
wire        m1_instr_illegal_fault;
wire        m1_instr_page_fault;
wire        m1_is_csr;
wire        m1_is_instr;
wire        m1_predtaken;
wire        m1_reg_wr;
wire        m1_ret;
wire        m1_ret_type;
wire [2:0]  m1_mem_ctr;
wire [2:0]  m1_reg_src;
wire [3:0]  m1_fstcause;
wire [4:0]  m1_branch_ctr;
wire [4:0]  m1_rd;
wire [11:0] m1_csr_rd;
wire [31:0] m1_alu_out;
wire [31:0] m1_csr_out;
wire [31:0] m1_imm;
wire [31:0] m1_instr;
wire [31:0] m1_pc;
wire [31:0] m1_pcplus4;
wire [31:0] m1_pcplusimm;
wire [31:0] m1_raw_csr_in;
wire [31:0] m1_raw_reg_in;
wire [31:0] m1_reg_out_b;

wire        m2_actual_jump;
wire        m2_csr_wr;
wire        m2_data_ren;
wire        m2_data_wen;
wire        m2_is_csr;
wire        m2_is_instr;
wire        m2_reg_wr;
wire        m2_ret;
wire        m2_ret_type;
wire        m2_fstcause_valid;
wire [2:0]  m2_mem_ctr;
wire [2:0]  m2_reg_src;
wire [3:0]  m2_fstcause;
wire [4:0]  m2_rd;
wire [11:0] m2_csr_rd;
wire [31:0] m2_alu_out;
wire [31:0] m2_csr_in;
wire [31:0] m2_csr_out;
wire [31:0] m2_imm;
wire [31:0] m2_instr;
wire [31:0] m2_jump_addr;
wire [31:0] m2_nextpc;
wire [31:0] m2_pc;
wire [31:0] m2_pcplus4;
wire [31:0] m2_pcplusimm;
wire [31:0] m2_raw_reg_in;

wire        next_MIE;
wire        next_MPIE;
wire        next_SIE;
wire        next_SPIE;
wire        next_SPP;
wire [1:0]  next_MPP;
wire [1:0]  nextprivilege;
wire [31:0] next_mcause;
wire [31:0] next_mepc;
wire [31:0] next_mtval;
wire [31:0] next_scause;
wire [31:0] next_sepc;
wire [31:0] next_stval;
wire        wb_csr_wr;
wire        wb_is_csr;
wire        wb_is_instr;
wire        wb_reg_wr;
wire [2:0]  wb_reg_src;
wire [4:0]  wb_rd;
wire [11:0] wb_csr_rd;
wire [31:0] wb_alu_out;
wire [31:0] wb_csr_in;
wire [31:0] wb_csr_out;
wire [31:0] wb_imm;
wire [31:0] wb_mem;
wire [31:0] wb_pcplus4;
wire [31:0] wb_pcplusimm;

wire [31:0] wb_reg_in;

privilege_mode privilege_mode (
    .clk             (clk),
    .rst_n (rst_n),
    .ret             (ret),
    .trap            (trap),
    .nextprivilege   (nextprivilege),
    .privilege       (privilege)
);

csr_file csr_file (
    .clk                     (clk),
    .rst_n (rst_n),

    .external_interrupt_clear(external_interrupt_clear),
    .external_interrupt_set  (external_interrupt_set),
    .timer_interrupt_clear   (timer_interrupt_clear),
    .timer_interrupt_set     (timer_interrupt_set),

    .csr_wr                  (wb_csr_wr),
    .next_MIE                (next_MIE),
    .next_MPIE               (next_MPIE),
    .next_SIE                (next_SIE),
    .next_SPIE               (next_SPIE),
    .next_SPP                (next_SPP),
    .ret                     (ret),
    .ret_type                (ret_type),
    .trap                    (trap),
    .trap_type               (trap_type),
    .wb_is_instr             (wb_is_instr),
    .next_MPP                (next_MPP),
    .csr_rd                  (wb_csr_rd),
    .csr_rs                  (ex1_csr_rd),
    .csr_in                  (wb_csr_in),
    .next_mcause             (next_mcause),
    .next_mepc               (next_mepc),
    .next_mtval              (next_mtval),
    .next_stval              (next_stval),
    .next_sepc               (next_sepc),
    .next_scause             (next_scause),
    .cur_MIE                 (cur_MIE),
    .cur_MPIE                (cur_MPIE),
    .cur_SIE                 (cur_SIE),
    .cur_SPIE                (cur_SPIE),
    .cur_SPP                 (cur_SPP),
    .cur_MPP                 (cur_MPP),
    .csr_out                 (ex1_csr_out),
    .cur_medeleg             (cur_medeleg),
    .cur_mepc                (cur_mepc),
    .cur_mideleg             (cur_mideleg),
    .cur_mie                 (cur_mie),
    .cur_mip                 (cur_mip),
    .cur_mtvec               (cur_mtvec),
    .cur_sepc                (cur_sepc),
    .cur_stvec               (cur_stvec)
);

trap_csr_bypass trap_csr_bypass (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (trap | ret | actual_jump),
    .stall      (mem_wait),
    .cur_MIE    (cur_MIE),
    .cur_MPIE   (cur_MPIE),
    .cur_SIE    (cur_SIE),
    .cur_SPIE   (cur_SPIE),
    .cur_SPP    (cur_SPP),
    .m2_csr_wr  (m2_csr_wr),
    .wb_csr_wr  (wb_csr_wr),
    .cur_MPP    (cur_MPP),
    .privilege  (privilege),
    .m1_fstcause(m1_fstcause),
    .m2_csr_rd  (m2_csr_rd),
    .wb_csr_rd  (wb_csr_rd),
    .cur_medeleg(cur_medeleg),
    .cur_mepc   (cur_mepc),
    .cur_mideleg(cur_mideleg),
    .cur_mie    (cur_mie),
    .cur_mip    (cur_mip),
    .cur_mtvec  (cur_mtvec),
    .cur_sepc   (cur_sepc),
    .cur_stvec  (cur_stvec),
    .m2_csr_in  (m2_csr_in),
    .wb_csr_in  (wb_csr_in),
    .interrupt_cause_valid(interrupt_cause_valid),
    .medeleg_exception_cause(medeleg_exception_cause),
    .mideleg_interrupt_cause(mideleg_interrupt_cause),
    .MIE        (MIE),
    .MPIE       (MPIE),
    .SIE        (SIE),
    .SPIE       (SPIE),
    .SPP        (SPP),
    .MPP        (MPP),
    .interrupt_cause(interrupt_cause),
    .medeleg    (medeleg),
    .mepc       (mepc),
    .mideleg    (mideleg),
    .mie        (mie),
    .mip        (mip),
    .mtvec      (mtvec),
    .sepc       (sepc),
    .stvec      (stvec)
);

reg_file reg_file (
    .clk      (clk),
    .rst_n (rst_n),
    .reg_wr   (wb_reg_wr),
    .rd       (wb_rd),
    .rs1      (ex1_rs1),
    .rs2      (ex1_rs2),
    .reg_in   (wb_reg_in),
    .reg_out_a(ex1_reg_out_a),
    .reg_out_b(ex1_reg_out_b)
);

if_stage if_stage (
    .clk                  (clk),
    .rst_n (rst_n),
    .flush                (trap | ret | actual_jump | (predtaken & !actual_jump & !reg_wait & !csr_wait & !mem_wait)),
    .stall                (reg_wait | csr_wait | mem_wait),
    .actual_jump          (actual_jump),
    .predtaken            (predtaken),
    .ret                  (ret),
    .ret_type             (ret_type),
    .trap                 (trap),
    .trap_type            (trap_type),
    .mepc                 (mepc),
    .mtvec                (mtvec),
    .sepc                 (sepc),
    .stvec                (stvec),

    .respond_fault_instr  (respond_fault_instr),
    .respond_valid_instr  (respond_valid_instr),
    .respond_data_instr   (respond_data_instr),
    .request_valid_instr  (request_valid_instr),
    .request_addr_instr   (request_addr_instr),

    .id_jump_addr         (id_jump_addr),
    .m2_jump_addr         (m2_jump_addr),

    .id_instr_access_fault(id_instr_access_fault),
    .id_instr_page_fault  (id_instr_page_fault),
    .id_is_instr          (id_is_instr),
    .id_instr             (id_instr),
    .id_pc                (id_pc),
    .id_pcplus4           (id_pcplus4)
);

id_stage id_stage (
    .clk                    (clk),
    .rst_n (rst_n),
    .flush                  (trap | ret | actual_jump),
    .stall                  (reg_wait | csr_wait | mem_wait),
    .privilege              (privilege),

    .predtaken              (predtaken),
    .id_jump_addr           (id_jump_addr),

    .id_instr_access_fault  (id_instr_access_fault),
    .id_instr_page_fault    (id_instr_page_fault),
    .id_is_instr            (id_is_instr),
    .id_instr               (id_instr),
    .id_pc                  (id_pc),
    .id_pcplus4             (id_pcplus4),
    .ex1_alu_src_a          (ex1_alu_src_a),
    .ex1_csr_wr             (ex1_csr_wr),
    .ex1_data_ren           (ex1_data_ren),
    .ex1_data_wen           (ex1_data_wen),
    .ex1_ebreak             (ex1_ebreak),
    .ex1_ecall              (ex1_ecall),
    .ex1_instr_access_fault (ex1_instr_access_fault),
    .ex1_instr_illegal_fault(ex1_instr_illegal_fault),
    .ex1_instr_page_fault   (ex1_instr_page_fault),
    .ex1_is_csr             (ex1_is_csr),
    .ex1_is_instr           (ex1_is_instr),
    .ex1_predtaken          (ex1_predtaken),
    .ex1_reg_out_a_used     (ex1_reg_out_a_used),
    .ex1_reg_out_b_used     (ex1_reg_out_b_used),
    .ex1_reg_wr             (ex1_reg_wr),
    .ex1_ret                (ex1_ret),
    .ex1_ret_type           (ex1_ret_type),
    .ex1_alu_src_b          (ex1_alu_src_b),
    .ex1_csr_src            (ex1_csr_src),
    .ex1_mem_ctr            (ex1_mem_ctr),
    .ex1_reg_src            (ex1_reg_src),
    .ex1_branch_ctr         (ex1_branch_ctr),
    .ex1_rd                 (ex1_rd),
    .ex1_rs1                (ex1_rs1),
    .ex1_rs2                (ex1_rs2),
    .ex1_alu_ctr            (ex1_alu_ctr),
    .ex1_csr_rd             (ex1_csr_rd),
    .ex1_imm                (ex1_imm),
    .ex1_instr              (ex1_instr),
    .ex1_pc                 (ex1_pc),
    .ex1_pcplus4            (ex1_pcplus4),
    .ex1_pcplusimm          (ex1_pcplusimm)
);

ex1_stage ex1_stage (
    .clk                    (clk),
    .rst_n (rst_n),
    .flush                  (trap | ret | actual_jump | ((reg_wait | csr_wait) & !mem_wait)),
    .stall                  (mem_wait),
    .csr_wait               (csr_wait),
    .reg_wait               (reg_wait),

    .m1_csr_wr              (m1_csr_wr),
    .m1_is_csr              (m1_is_csr),
    .m1_reg_wr              (m1_reg_wr),
    .m2_csr_wr              (m2_csr_wr),
    .m2_is_csr              (m2_is_csr),
    .m2_reg_wr              (m2_reg_wr),
    .wb_csr_wr              (wb_csr_wr),
    .wb_is_csr              (wb_is_csr),
    .wb_reg_wr              (wb_reg_wr),
    .m1_reg_src             (m1_reg_src),
    .m2_reg_src             (m2_reg_src),
    .m1_rd                  (m1_rd),
    .m2_rd                  (m2_rd),
    .wb_rd                  (wb_rd),
    .m1_csr_rd              (m1_csr_rd),
    .m2_csr_rd              (m2_csr_rd),
    .wb_csr_rd              (wb_csr_rd),
    .ex1_csr_out            (ex1_csr_out),
    .ex1_reg_out_a          (ex1_reg_out_a),
    .ex1_reg_out_b          (ex1_reg_out_b),
    .m1_raw_reg_in          (m1_raw_reg_in),
    .m2_raw_reg_in          (m2_raw_reg_in),
    .wb_reg_in              (wb_reg_in),

    .ex1_alu_src_a          (ex1_alu_src_a),
    .ex1_csr_wr             (ex1_csr_wr),
    .ex1_data_ren           (ex1_data_ren),
    .ex1_data_wen           (ex1_data_wen),
    .ex1_ebreak             (ex1_ebreak),
    .ex1_ecall              (ex1_ecall),
    .ex1_instr_access_fault (ex1_instr_access_fault),
    .ex1_instr_illegal_fault(ex1_instr_illegal_fault),
    .ex1_instr_page_fault   (ex1_instr_page_fault),
    .ex1_is_csr             (ex1_is_csr),
    .ex1_is_instr           (ex1_is_instr),
    .ex1_predtaken          (ex1_predtaken),
    .ex1_reg_out_a_used     (ex1_reg_out_a_used),
    .ex1_reg_out_b_used     (ex1_reg_out_b_used),
    .ex1_reg_wr             (ex1_reg_wr),
    .ex1_ret                (ex1_ret),
    .ex1_ret_type           (ex1_ret_type),
    .ex1_alu_src_b          (ex1_alu_src_b),
    .ex1_csr_src            (ex1_csr_src),
    .ex1_mem_ctr            (ex1_mem_ctr),
    .ex1_reg_src            (ex1_reg_src),
    .ex1_branch_ctr         (ex1_branch_ctr),
    .ex1_rd                 (ex1_rd),
    .ex1_rs1                (ex1_rs1),
    .ex1_rs2                (ex1_rs2),
    .ex1_alu_ctr            (ex1_alu_ctr),
    .ex1_csr_rd             (ex1_csr_rd),
    .ex1_imm                (ex1_imm),
    .ex1_instr              (ex1_instr),
    .ex1_pc                 (ex1_pc),
    .ex1_pcplus4            (ex1_pcplus4),
    .ex1_pcplusimm          (ex1_pcplusimm),
    .ex2_aluinausem1        (ex2_aluinausem1),
    .ex2_aluinbusem1        (ex2_aluinbusem1),
    .ex2_csr_wr             (ex2_csr_wr),
    .ex2_data_ren           (ex2_data_ren),
    .ex2_data_wen           (ex2_data_wen),
    .ex2_ebreak             (ex2_ebreak),
    .ex2_ecall              (ex2_ecall),
    .ex2_instr_access_fault (ex2_instr_access_fault),
    .ex2_instr_illegal_fault(ex2_instr_illegal_fault),
    .ex2_instr_page_fault   (ex2_instr_page_fault),
    .ex2_is_csr             (ex2_is_csr),
    .ex2_is_instr           (ex2_is_instr),
    .ex2_predtaken          (ex2_predtaken),
    .ex2_reg_wr             (ex2_reg_wr),
    .ex2_ret                (ex2_ret),
    .ex2_ret_type           (ex2_ret_type),
    .ex2_rs1usem1           (ex2_rs1usem1),
    .ex2_rs2usem1           (ex2_rs2usem1),
    .ex2_csr_src            (ex2_csr_src),
    .ex2_mem_ctr            (ex2_mem_ctr),
    .ex2_reg_src            (ex2_reg_src),
    .ex2_branch_ctr         (ex2_branch_ctr),
    .ex2_rd                 (ex2_rd),
    .ex2_alu_ctr            (ex2_alu_ctr),
    .ex2_csr_rd             (ex2_csr_rd),
    .ex2_alu_in_a           (ex2_alu_in_a),
    .ex2_alu_in_b           (ex2_alu_in_b),
    .ex2_csr_out            (ex2_csr_out),
    .ex2_imm                (ex2_imm),
    .ex2_instr              (ex2_instr),
    .ex2_pc                 (ex2_pc),
    .ex2_pcplus4            (ex2_pcplus4),
    .ex2_pcplusimm          (ex2_pcplusimm),
    .ex2_reg_out_a          (ex2_reg_out_a),
    .ex2_reg_out_b          (ex2_reg_out_b)
);

ex2_stage ex2_stage (
    .clk                    (clk),
    .rst_n (rst_n),
    .flush                  (trap | ret | actual_jump),
    .stall                  (mem_wait),

    .ex2_aluinausem1        (ex2_aluinausem1),
    .ex2_aluinbusem1        (ex2_aluinbusem1),
    .ex2_csr_wr             (ex2_csr_wr),
    .ex2_data_ren           (ex2_data_ren),
    .ex2_data_wen           (ex2_data_wen),
    .ex2_ebreak             (ex2_ebreak),
    .ex2_ecall              (ex2_ecall),
    .ex2_instr_access_fault (ex2_instr_access_fault),
    .ex2_instr_illegal_fault(ex2_instr_illegal_fault),
    .ex2_instr_page_fault   (ex2_instr_page_fault),
    .ex2_is_csr             (ex2_is_csr),
    .ex2_is_instr           (ex2_is_instr),
    .ex2_predtaken          (ex2_predtaken),
    .ex2_reg_wr             (ex2_reg_wr),
    .ex2_ret                (ex2_ret),
    .ex2_ret_type           (ex2_ret_type),
    .ex2_rs1usem1           (ex2_rs1usem1),
    .ex2_rs2usem1           (ex2_rs2usem1),
    .ex2_csr_src            (ex2_csr_src),
    .ex2_mem_ctr            (ex2_mem_ctr),
    .ex2_reg_src            (ex2_reg_src),
    .ex2_branch_ctr         (ex2_branch_ctr),
    .ex2_rd                 (ex2_rd),
    .ex2_alu_ctr            (ex2_alu_ctr),
    .ex2_csr_rd             (ex2_csr_rd),
    .ex2_alu_in_a           (ex2_alu_in_a),
    .ex2_alu_in_b           (ex2_alu_in_b),
    .ex2_csr_out            (ex2_csr_out),
    .ex2_imm                (ex2_imm),
    .ex2_instr              (ex2_instr),
    .ex2_pc                 (ex2_pc),
    .ex2_pcplus4            (ex2_pcplus4),
    .ex2_pcplusimm          (ex2_pcplusimm),
    .ex2_reg_out_a          (ex2_reg_out_a),
    .ex2_reg_out_b          (ex2_reg_out_b),
    .m1_zf                  (m1_zf),
    .m1_cf                  (m1_cf),
    .m1_sf                  (m1_sf),
    .m1_of                  (m1_of),
    .m1_csr_wr              (m1_csr_wr),
    .m1_data_ren            (m1_data_ren),
    .m1_data_wen            (m1_data_wen),
    .m1_ebreak              (m1_ebreak),
    .m1_ecall               (m1_ecall),
    .m1_instr_access_fault  (m1_instr_access_fault),
    .m1_instr_illegal_fault (m1_instr_illegal_fault),
    .m1_instr_page_fault    (m1_instr_page_fault),
    .m1_is_csr              (m1_is_csr),
    .m1_is_instr            (m1_is_instr),
    .m1_predtaken           (m1_predtaken),
    .m1_reg_wr              (m1_reg_wr),
    .m1_ret                 (m1_ret),
    .m1_ret_type            (m1_ret_type),
    .m1_mem_ctr             (m1_mem_ctr),
    .m1_reg_src             (m1_reg_src),
    .m1_branch_ctr          (m1_branch_ctr),
    .m1_rd                  (m1_rd),
    .m1_csr_rd              (m1_csr_rd),
    .m1_alu_out             (m1_alu_out),
    .m1_csr_out             (m1_csr_out),
    .m1_imm                 (m1_imm),
    .m1_instr               (m1_instr),
    .m1_pc                  (m1_pc),
    .m1_pcplus4             (m1_pcplus4),
    .m1_pcplusimm           (m1_pcplusimm),
    .m1_raw_csr_in          (m1_raw_csr_in),
    .m1_raw_reg_in          (m1_raw_reg_in),
    .m1_reg_out_b           (m1_reg_out_b)
);

m1_stage m1_stage (
    .clk                   (clk),
    .rst_n (rst_n),
    .flush                 (trap | ret | actual_jump),
    .stall                 (mem_wait),
    .privilege             (privilege),
    .mepc                  (mepc),
    .sepc                  (sepc),
    .request_valid_data    (request_valid_data),
    .request_write_data    (request_write_data),
    .request_en_data       (request_en_data),
    .request_addr_data     (request_addr_data),
    .request_data_data     (request_data_data),

    .m1_fstcause           (m1_fstcause),

    .m1_zf                 (m1_zf),
    .m1_cf                 (m1_cf),
    .m1_sf                 (m1_sf),
    .m1_of                 (m1_of),
    .m1_csr_wr             (m1_csr_wr),
    .m1_data_ren           (m1_data_ren),
    .m1_data_wen           (m1_data_wen),
    .m1_ebreak             (m1_ebreak),
    .m1_ecall              (m1_ecall),
    .m1_instr_access_fault (m1_instr_access_fault),
    .m1_instr_illegal_fault(m1_instr_illegal_fault),
    .m1_instr_page_fault   (m1_instr_page_fault),
    .m1_is_csr             (m1_is_csr),
    .m1_is_instr           (m1_is_instr),
    .m1_predtaken          (m1_predtaken),
    .m1_reg_wr             (m1_reg_wr),
    .m1_ret                (m1_ret),
    .m1_ret_type           (m1_ret_type),
    .m1_mem_ctr            (m1_mem_ctr),
    .m1_reg_src            (m1_reg_src),
    .m1_branch_ctr         (m1_branch_ctr),
    .m1_rd                 (m1_rd),
    .m1_csr_rd             (m1_csr_rd),
    .m1_alu_out            (m1_alu_out),
    .m1_csr_out            (m1_csr_out),
    .m1_imm                (m1_imm),
    .m1_instr              (m1_instr),
    .m1_pc                 (m1_pc),
    .m1_pcplus4            (m1_pcplus4),
    .m1_pcplusimm          (m1_pcplusimm),
    .m1_raw_csr_in         (m1_raw_csr_in),
    .m1_raw_reg_in         (m1_raw_reg_in),
    .m1_reg_out_b          (m1_reg_out_b),
    .m2_actual_jump        (m2_actual_jump),
    .m2_csr_wr             (m2_csr_wr),
    .m2_data_ren           (m2_data_ren),
    .m2_data_wen           (m2_data_wen),
    .m2_is_csr             (m2_is_csr),
    .m2_is_instr           (m2_is_instr),
    .m2_reg_wr             (m2_reg_wr),
    .m2_ret                (m2_ret),
    .m2_ret_type           (m2_ret_type),
    .m2_fstcause_valid     (m2_fstcause_valid),
    .m2_mem_ctr            (m2_mem_ctr),
    .m2_reg_src            (m2_reg_src),
    .m2_fstcause           (m2_fstcause),
    .m2_rd                 (m2_rd),
    .m2_csr_rd             (m2_csr_rd),
    .m2_alu_out            (m2_alu_out),
    .m2_csr_in             (m2_csr_in),
    .m2_csr_out            (m2_csr_out),
    .m2_imm                (m2_imm),
    .m2_instr              (m2_instr),
    .m2_jump_addr          (m2_jump_addr),
    .m2_nextpc             (m2_nextpc),
    .m2_pc                 (m2_pc),
    .m2_pcplus4            (m2_pcplus4),
    .m2_pcplusimm          (m2_pcplusimm),
    .m2_raw_reg_in         (m2_raw_reg_in)
);

m2_stage m2_stage (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .flush                 (trap | mem_wait),
    .interrupt_cause_valid (interrupt_cause_valid),
    .medeleg_exception_cause(medeleg_exception_cause),
    .mideleg_interrupt_cause(mideleg_interrupt_cause),
    .MIE                   (MIE),
    .MPIE                  (MPIE),
    .SIE                   (SIE),
    .SPIE                  (SPIE),
    .SPP                   (SPP),
    .MPP                   (MPP),
    .privilege             (privilege),
    .interrupt_cause       (interrupt_cause),
    .medeleg               (medeleg),
    .mideleg               (mideleg),
    .mie                   (mie),
    .mip                   (mip),
    .actual_jump           (actual_jump),
    .mem_wait              (mem_wait),
    .next_MIE              (next_MIE),
    .next_MPIE             (next_MPIE),
    .next_SIE              (next_SIE),
    .next_SPIE             (next_SPIE),
    .ret                   (ret),
    .ret_type              (ret_type),
    .trap                  (trap),
    .trap_type             (trap_type),
    .next_SPP              (next_SPP),
    .next_MPP              (next_MPP),
    .nextprivilege         (nextprivilege),
    .next_mcause           (next_mcause),
    .next_mepc             (next_mepc),
    .next_mtval            (next_mtval),
    .next_scause           (next_scause),
    .next_sepc             (next_sepc),
    .next_stval            (next_stval),
    .respond_fault_data    (respond_fault_data),
    .respond_valid_data    (respond_valid_data),
    .respond_data_data     (respond_data_data),
    .m2_actual_jump        (m2_actual_jump),
    .m2_csr_wr             (m2_csr_wr),
    .m2_data_ren           (m2_data_ren),
    .m2_data_wen           (m2_data_wen),
    .m2_is_csr             (m2_is_csr),
    .m2_is_instr           (m2_is_instr),
    .m2_reg_wr             (m2_reg_wr),
    .m2_ret                (m2_ret),
    .m2_ret_type           (m2_ret_type),
    .m2_fstcause_valid     (m2_fstcause_valid),
    .m2_mem_ctr            (m2_mem_ctr),
    .m2_reg_src            (m2_reg_src),
    .m2_fstcause           (m2_fstcause),
    .m2_rd                 (m2_rd),
    .m2_csr_rd             (m2_csr_rd),
    .m2_alu_out            (m2_alu_out),
    .m2_csr_in             (m2_csr_in),
    .m2_csr_out            (m2_csr_out),
    .m2_imm                (m2_imm),
    .m2_instr              (m2_instr),
    .m2_nextpc             (m2_nextpc),
    .m2_pc                 (m2_pc),
    .m2_pcplus4            (m2_pcplus4),
    .m2_pcplusimm          (m2_pcplusimm),
    .m2_raw_reg_in         (m2_raw_reg_in),
    .wb_csr_wr             (wb_csr_wr),
    .wb_is_csr             (wb_is_csr),
    .wb_is_instr           (wb_is_instr),
    .wb_reg_wr             (wb_reg_wr),
    .wb_reg_src            (wb_reg_src),
    .wb_rd                 (wb_rd),
    .wb_csr_rd             (wb_csr_rd),
    .wb_alu_out            (wb_alu_out),
    .wb_csr_in             (wb_csr_in),
    .wb_csr_out            (wb_csr_out),
    .wb_imm                (wb_imm),
    .wb_mem                (wb_mem),
    .wb_pcplus4            (wb_pcplus4),
    .wb_pcplusimm          (wb_pcplusimm)
);

wb_stage wb_stage (
    .wb_reg_in(wb_reg_in),

    .wb_reg_src(wb_reg_src),
    .wb_alu_out(wb_alu_out),
    .wb_csr_out(wb_csr_out),
    .wb_imm(wb_imm),
    .wb_mem(wb_mem),
    .wb_pcplus4(wb_pcplus4),
    .wb_pcplusimm(wb_pcplusimm)
);

endmodule
