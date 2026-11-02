`timescale 1ns / 1ns

// 需确保 privilege = 2'h0, 2'h1, 2'h3
module idu (
    input      [1:0]  privilege,
    input      [31:0] instr,

    output reg        ebreak,
    output reg        ecall,
    output reg        instr_illegal_fault,

    output reg        ret,
    output reg        ret_type,

    output reg        wfi,

    output reg [1:0]  alu_src_a, // 0: 0, 1: rs1, 2: imm, 3: 0
    output reg [1:0]  alu_src_b, // 0: 0, 1: rs2, 2: imm, 3: csr_out
    output reg [5:0]  alu_ctr,

    output reg        reg_out_a_used,
    output reg        reg_out_b_used,
    output     [4:0]  rs1,
    output     [4:0]  rs2,

    output reg        reg_wr,
    output reg [2:0]  reg_src, // 0: alu_out, 1: pc + 4, 2: pc + imm, 3: mem, 4: csr_out
    output     [4:0]  rd,

    output reg        csr_wr,
    output reg        is_csr,
    output     [11:0] csr_rd,

    output reg        mem_valid,
    output reg [4:0]  mem_ctr, // 高 2 位 0: R, 1: W, 2: sfence.vma, 3: fence.i

    output reg        predtaken,
    output reg [4:0]  branch_ctr, // 高 2 位 1: B, 2: jal, 3: jalr

    output reg [31:0] imm
);

wire [6:0] opcode       = instr[6:0];
wire [2:0] funct3       = instr[14:12];
wire [6:0] funct7       = instr[31:25];
wire [11:0] system_code = instr[31:20];

assign rs1    = instr[19:15];
assign rs2    = instr[24:20];
assign rd     = instr[11:7];
assign csr_rd = instr[31:20];

wire csr_exist = csr_rd == 12'h100 ||
                 csr_rd == 12'h104 ||
                 csr_rd == 12'h105 ||
                 csr_rd == 12'h140 ||
                 csr_rd == 12'h141 ||
                 csr_rd == 12'h142 ||
                 csr_rd == 12'h143 ||
                 csr_rd == 12'h144 ||
                 csr_rd == 12'h180 ||
                 csr_rd == 12'h300 ||
                 csr_rd == 12'h301 ||
                 csr_rd == 12'h302 ||
                 csr_rd == 12'h303 ||
                 csr_rd == 12'h304 ||
                 csr_rd == 12'h305 ||
                 csr_rd == 12'h340 ||
                 csr_rd == 12'h341 ||
                 csr_rd == 12'h342 ||
                 csr_rd == 12'h343 ||
                 csr_rd == 12'h344 ||
                 csr_rd == 12'hB00 ||
                 csr_rd == 12'hB02 ||
                 csr_rd == 12'hB80 ||
                 csr_rd == 12'hB82 ||
                 csr_rd == 12'hF14;

wire system_exist = system_code == 12'h0 ||
                    system_code == 12'h1 ||
                    system_code == 12'h302 ||
                    system_code == 12'h102 ||
                    system_code == 12'h105 ||
                    system_code[11:5] == 7'h09;

wire fence_exist = funct3 == 3'h0 || funct3 == 3'h1;

wire csrr_wr_en = funct3 == 3'h1 || rs1 != 5'h0;
wire csri_wr_en = funct3 == 3'h5 || instr[19:15] != 5'h0;

always @(*) begin
    imm = 32'h0;
    instr_illegal_fault = 1'h0;
    ebreak = 1'h0;
    ecall = 1'h0;
    reg_wr = 1'h0;
    reg_src = 3'h0;
    ret = 1'h0;
    ret_type = 1'h0;
    wfi = 1'h0;
    csr_wr = 1'h0;
    is_csr = 1'h0;
    alu_src_a = 2'h0;
    alu_src_b = 2'h0;
    alu_ctr = 6'h0;
    reg_out_a_used = 1'h0;
    reg_out_b_used = 1'h0;
    mem_valid = 1'h0;
    mem_ctr = 5'h0;
    predtaken = 1'h0;
    branch_ctr = 5'h0;
    case (opcode)
        // R 型指令
        7'h33: begin
            // 检查 funct7
            instr_illegal_fault = funct7[6] != 1'h0 || funct7[4:0] != 5'h0 ||
                                  (funct3 != 3'h0 && funct3 != 3'h5 && funct7[5] == 1'h1);
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h0;
            alu_src_a = 2'h1;
            alu_src_b = 2'h1;
            alu_ctr = {2'h0, funct7[5], funct3};
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
        end
        // I 型指令
        7'h13: begin
            case (funct3)
                3'h1, 3'h5: imm = {27'h0, instr[24:20]};
                default:    imm = {{20{instr[31]}}, instr[31:20]};
            endcase
            // 检查 srli 和 srai 的 funct7
            instr_illegal_fault = (funct3 == 3'h1 && instr[31:25] != 7'h0) ||
                                  (funct3 == 3'h5 && (instr[31] != 1'h0 || instr[29:25] != 5'h0));
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h0;
            alu_src_a = 2'h1;
            alu_src_b = 2'h2;
            alu_ctr = {2'h0, funct3 == 3'h5 ? funct7[5] : 1'h0, funct3};
            reg_out_a_used = !instr_illegal_fault;
        end
        // load 型指令
        7'h3 : begin
            imm = {{20{instr[31]}}, instr[31:20]};
            // 检查 funct3
            instr_illegal_fault = funct3 == 3'h3 || funct3 == 3'h6 || funct3 == 3'h7;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h3;
            alu_src_a = 2'h1;
            alu_src_b = 2'h2;
            alu_ctr = 6'h0;
            reg_out_a_used = !instr_illegal_fault;
            mem_valid = !instr_illegal_fault;
            mem_ctr = {2'h0, funct3};
        end
        // jalr
        7'h67: begin
            imm = {{20{instr[31]}}, instr[31:20]};
            // 检查 funct3
            instr_illegal_fault = funct3 != 3'h0;
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h1;
            alu_src_a = 2'h1;
            alu_src_b = 2'h2;
            alu_ctr = 6'h0;
            reg_out_a_used = !instr_illegal_fault;
            branch_ctr = !instr_illegal_fault ? {2'h3, 3'h0} : 5'h0;
        end
        // lui
        7'h37: begin
            imm = {instr[31:12], 12'h0};
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h0;
            alu_src_a = 2'h0;
            alu_src_b = 2'h2;
            alu_ctr = 6'h0;
        end
        // auipc
        7'h17: begin
            imm = {instr[31:12], 12'h0};
            reg_wr = !instr_illegal_fault;
            reg_src = 3'h2;
        end
        // S 型指令
        7'h23: begin
            imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            // 检查 funct3
            instr_illegal_fault = funct3 >= 3'h3;
            alu_src_a = 2'h1;
            alu_src_b = 2'h2;
            alu_ctr = 6'h0;
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
            mem_valid = !instr_illegal_fault;
            mem_ctr = {2'h1, funct3};
        end
        // B 型指令
        7'h63: begin
            imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'h0};
            // 检查 funct3
            instr_illegal_fault = funct3 == 3'h2 || funct3 == 3'h3;
            alu_src_a = 2'h1;
            alu_src_b = 2'h1;
            alu_ctr = 6'h8;
            reg_out_a_used = !instr_illegal_fault;
            reg_out_b_used = !instr_illegal_fault;
            predtaken = !instr_illegal_fault && imm[31] == 1'h1;
            branch_ctr = !instr_illegal_fault ? {2'h1, funct3} : 5'h0;
        end
        // jal
        7'h6f: begin
            imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'h0};
            reg_wr = 1'h1;
            reg_src = 3'h1;
            predtaken = 1'h1;
            branch_ctr = !instr_illegal_fault ? {2'h2, 3'h0} : 5'h0;
        end
        7'h73: begin
            case (funct3)
                // csrr
                3'h1, 3'h2, 3'h3: begin
                    instr_illegal_fault = !csr_exist || privilege < csr_rd[9:8] || (csrr_wr_en && csr_rd[11:10] == 2'h3);
                    reg_wr = !instr_illegal_fault;
                    reg_src = 3'h4;
                    csr_wr = !instr_illegal_fault && csrr_wr_en;
                    is_csr = !instr_illegal_fault;
                    alu_src_a = 2'h1;
                    alu_src_b = funct3[1:0] == 2'h2 || funct3[1:0] == 2'h3 ? 2'h3 : 2'h0;
                    alu_ctr = funct3[1:0] == 2'h2 ? 6'h6 : (funct3[1:0] == 2'h3 ? 6'h17 : 6'h0);
                    reg_out_a_used = !instr_illegal_fault && csrr_wr_en;
                end
                // csrri
                3'h5, 3'h6, 3'h7: begin
                    imm = {27'h0, instr[19:15]};
                    instr_illegal_fault = !csr_exist || privilege < csr_rd[9:8] || (csri_wr_en && csr_rd[11:10] == 2'h3);
                    reg_wr = !instr_illegal_fault;
                    reg_src = 3'h4;
                    csr_wr = !instr_illegal_fault && csri_wr_en;
                    is_csr = !instr_illegal_fault;
                    alu_src_a = 2'h2;
                    alu_src_b = funct3[1:0] == 2'h2 || funct3[1:0] == 2'h3 ? 2'h3 : 2'h0;
                    alu_ctr = funct3[1:0] == 2'h2 ? 6'h6 : (funct3[1:0] == 2'h3 ? 6'h17 : 6'h0);
                end
                // system
                3'h0: begin
                    instr_illegal_fault = rd != 5'h0 || !system_exist ||
                                          (system_code == 12'h302 && privilege < 2'h3) ||
                                          (system_code == 12'h102 && privilege < 2'h1) ||
                                          (system_code[11:5] == 7'h09 && privilege < 2'h1) ||
                                          (system_code[11:5] != 7'h09 && rs1 != 5'h0);
                    ebreak = !instr_illegal_fault && system_code == 12'h1;
                    ecall = !instr_illegal_fault && system_code == 12'h0;
                    ret = !instr_illegal_fault && (system_code == 12'h302 || system_code == 12'h102);
                    ret_type = system_code == 12'h102;
                    wfi = !instr_illegal_fault && system_code == 12'h105;
                    mem_valid = !instr_illegal_fault && system_code[11:5] == 7'h09;
                    mem_ctr = {2'h2, 3'h0};
                end
                // invalid
                default: begin
                    instr_illegal_fault = 1'h1;
                end
            endcase
        end
        // fence
        7'h0f: begin
            instr_illegal_fault = rd != 5'h0 || rs1 != 5'h0 || !fence_exist ||
                                  (funct3 == 3'h0 && instr[31:28] != 4'h0 && instr[31:28] != 4'h8) ||
                                  (funct3 == 3'h1 && instr[31:20] != 12'h0) ||
                                  (funct3 == 3'h0 && instr[31:28] == 4'h8 && (instr[27:24] != 4'h3 || instr[23:20] != 4'h3));
            mem_valid = !instr_illegal_fault && funct3 == 3'h1;
            mem_ctr = {2'h3, 3'h0};
        end
        // invalid
        default: begin
            instr_illegal_fault = 1'h1;
        end
    endcase
end

endmodule
