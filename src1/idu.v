`timescale 1ns / 1ns

// mstatus, privilege 改变必须刷新流水线
// csr 是否存在后续写入时判定
module idu (
    input             is_instr,
    input             TSR, // 禁止 S sret
    input             TVM, // 禁止 S 读写 satp 和 sfence.vma
    input             TW,  // 禁止 S wfi
    input      [1:0]  privilege,
    input      [30:0] pc,
    input      [31:0] instr,

    output reg        ebreak,
    output reg        ecall,
    output reg        instr_illegal_fault,

    output reg        ret,
    output reg        ret_type,

    output reg        wfi,

    output reg        alu_src_a, // 0: rs1, 1: 0
    output reg        alu_src_b, // 0: rs2, 1: imm
    output reg [3:0]  alu_ctr,

    output reg        reg_out_a_used,
    output reg        reg_out_b_used,
    output     [4:0]  rs1,
    output     [4:0]  rs2,

    output reg        reg_wr,
    output reg [2:0]  reg_src, // 0: alu_out, 1: pcplus, 2: pcplusimm, 3: mem, 4: csr_out
    output     [4:0]  rd,

    output reg        csr_wr,
    output reg        is_csr,
    output reg [2:0]  csr_ctr,
    output     [11:0] csr_rd,

    output reg        mem_valid,
    output reg [4:0]  mem_ctr, // 高 2 位 0: R, 1: W, 2: sfence.vma, 3: fence.i

    output reg        jump,
    output reg [4:0]  branch_ctr, // 高 2 位 1: B, 2: jalr
    output     [30:0] pcplusimm,

    output reg [31:0] imm
);

wire [6:0]  opcode      = instr[6:0];
wire [2:0]  funct3      = instr[14:12];
wire [6:0]  funct7      = instr[31:25];
wire [11:0] system_code = instr[31:20];

assign rs1    = instr[19:15];
assign rs2    = instr[24:20];
assign rd     = instr[11:7];
assign csr_rd = instr[31:20];

wire system_exist = system_code == 12'h0   ||   // ecall
                    system_code == 12'h1   ||   // ebreak
                    system_code == 12'h302 ||   // mret
                    system_code == 12'h102 ||   // sret
                    system_code == 12'h105 ||   // wfi
                    system_code[11:5] == 7'h9;  // sfence.vma

reg [30:0] pc_imm;

assign pcplusimm = pc + pc_imm;

always @(*) begin
    ebreak = 1'h0;
    ecall = 1'h0;
    instr_illegal_fault = 1'h0;
    ret = 1'h0;
    ret_type = system_code[9] == 1'h0;
    wfi = 1'h0;
    alu_src_a = 1'h0;
    alu_src_b = 1'h1;
    alu_ctr = 4'h0;
    reg_out_a_used = 1'h0;
    reg_out_b_used = 1'h0;
    reg_wr = 1'h0;
    reg_src = 3'h0;
    csr_wr = funct3[1:0] == 2'h1 || instr[19:15] != 5'h0;
    is_csr = 1'h0;
    csr_ctr = funct3;
    mem_valid = 1'h0;
    mem_ctr = {2'h0, funct3};
    jump = 1'h0;
    branch_ctr = 5'h0;
    pc_imm = {instr[31:12], 11'h0};
    imm = {{20{instr[31]}}, instr[31:20]};
    case (opcode)
        // R 型指令
        7'h33: begin
            // 检查 funct7
            instr_illegal_fault = funct7[6] != 1'h0 || funct7[4:0] != 5'h0 ||
                                  (funct3 != 3'h0 && funct3 != 3'h5 && funct7[5] == 1'h1);
            alu_src_a = 1'h0;
            alu_src_b = 1'h0;
            alu_ctr = {funct7[5], funct3};
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h0;
        end
        // I 型指令
        7'h13: begin
            // 检查 srli 和 srai 的 funct7
            instr_illegal_fault = (funct3 == 3'h1 && instr[31:25] != 7'h0) ||
                                  (funct3 == 3'h5 && (instr[31] != 1'h0 || instr[29:25] != 5'h0));
            alu_src_a = 1'h0;
            alu_src_b = 1'h1;
            alu_ctr = {funct3 == 3'h5 && instr[30] == 1'h1, funct3};
            reg_out_a_used = !instr_illegal_fault;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h0;
            imm = {{20{instr[31]}}, instr[31:20]}; // alu 需确保移位只看 imm[4:0]
        end
        // load 型指令
        7'h3 : begin
            // 检查 funct3
            instr_illegal_fault = funct3 == 3'h3 || funct3 == 3'h6 || funct3 == 3'h7;
            alu_src_a = 1'h0;
            alu_src_b = 1'h1;
            alu_ctr = 4'h0;
            reg_out_a_used = !instr_illegal_fault;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h3;
            mem_valid = !instr_illegal_fault;
            mem_ctr = {2'h0, funct3};
            imm = {{20{instr[31]}}, instr[31:20]};
        end
        // jalr
        7'h67: begin
            // 检查 funct3
            instr_illegal_fault = funct3 != 3'h0;
            alu_src_a = 1'h0;
            alu_src_b = 1'h1;
            alu_ctr = 4'h0;
            reg_out_a_used = !instr_illegal_fault;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h1;
            branch_ctr = !instr_illegal_fault ? {2'h2, 3'h0} : 5'h0;
            imm = {{20{instr[31]}}, instr[31:20]};
        end
        // lui
        7'h37: begin
            alu_src_a = 1'h1;
            alu_src_b = 1'h1;
            alu_ctr = 4'h0;
            reg_wr = 1'h1;
            reg_src = 3'h0;
            imm = {instr[31:12], 12'h0};
        end
        // auipc
        7'h17: begin
            reg_wr = 1'h1;
            reg_src = 3'h2;
            pc_imm = {instr[31:12], 11'h0};
        end
        // S 型指令
        7'h23: begin
            // 检查 funct3
            instr_illegal_fault = funct3 >= 3'h3;
            alu_src_a = 1'h0;
            alu_src_b = 1'h1;
            alu_ctr = 4'h0;
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
            mem_valid = !instr_illegal_fault;
            mem_ctr = {2'h1, funct3};
            imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end
        // B 型指令
        7'h63: begin
            // 检查 funct3
            instr_illegal_fault = funct3 == 3'h2 || funct3 == 3'h3;
            alu_src_a = 1'h0;
            alu_src_b = 1'h0;
            alu_ctr = 4'h8;
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
            jump = !instr_illegal_fault && instr[31] == 1'h1;
            branch_ctr = !instr_illegal_fault ? {2'h1, funct3} : 5'h0;
            pc_imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8]};
        end
        // jal
        7'h6f: begin
            reg_wr = 1'h1;
            reg_src = 3'h1;
            jump = 1'h1;
            pc_imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21]};
        end
        7'h73: begin
            case (funct3)
                // system
                3'h0: begin
                    instr_illegal_fault = rd != 5'h0 || !system_exist ||
                                          (system_code[11:5] != 7'h9 && rs1 != 5'h0) ||
                                          privilege < system_code[9:8] ||
                                          (TSR && privilege == 2'h1 && system_code == 12'h102) ||
                                          (TVM && privilege == 2'h1 && system_code[11:5] == 7'h9) ||
                                          (TW && privilege == 2'h1 && system_code == 12'h105);
                    ebreak = !instr_illegal_fault && system_code == 12'h1;
                    ecall = !instr_illegal_fault && system_code == 12'h0;
                    ret = !instr_illegal_fault && (system_code == 12'h302 || system_code == 12'h102);
                    // ret_type = system_code[9] == 1'h0;
                    wfi = !instr_illegal_fault && system_code == 12'h105;
                    mem_valid = !instr_illegal_fault && system_code[11:5] == 7'h9;
                    mem_ctr = {2'h2, 3'h0};
                end
                // csrr, csrri
                default: begin
                    instr_illegal_fault = funct3 == 3'h4 ||
                                          privilege < csr_rd[9:8] ||
                                          (TVM && privilege == 2'h1 && csr_rd == 12'h180) ||
                                          (csr_rd[11:10] == 2'h3 && (funct3[1:0] == 2'h1 || instr[19:15] != 5'h0));
                    // reg_out_a_used = !instr_illegal_fault && csrr_wr_en;
                    // 该处目前可以删除，因为 csr 指令会等待所有指令排空后再读取，无需 reg_bypass 控制
                    reg_wr = !instr_illegal_fault;
                    reg_src = 3'h4;
                    is_csr = !instr_illegal_fault;
                    // csr_ctr = funct3;
                    imm = {27'h0, instr[19:15]};
                end
            endcase
        end
        // fence
        7'hf: begin
            instr_illegal_fault = rd != 5'h0 || rs1 != 5'h0 || funct3 >= 3'h2 ||
                                  (funct3 == 3'h0 && instr[31:20] != 12'h833 && instr[31:28] != 4'h0) ||
                                  (funct3 == 3'h1 && instr[31:20] != 12'h0);
            mem_valid = !instr_illegal_fault && funct3 == 3'h1;
            mem_ctr = {2'h3, 3'h0};
        end
        // invalid
        default: begin
            instr_illegal_fault = 1'h1;
        end
    endcase
    if (!is_instr) begin
        ebreak = 1'h0;
        ecall = 1'h0;
        instr_illegal_fault = 1'h0;
        ret = 1'h0;
        wfi = 1'h0;
        reg_out_a_used = 1'h0;
        reg_out_b_used = 1'h0;
        reg_wr = 1'h0;
        is_csr = 1'h0;
        mem_valid = 1'h0;
        jump = 1'h0;
        branch_ctr = 5'h0;
    end
end

endmodule
