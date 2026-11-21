`timescale 1ns / 1ns

module if_stage (
    // 全局参数
    input             clk,
    input             rst_n,
    input             flush,
    input             stall,
    input             id_jump,
    input             m2_jump,
    input             ret,
    input             ret_type,
    input             trap,
    input             trap_type,
    input      [31:0] mepc,
    input      [31:0] mtvec,
    input      [31:0] sepc,
    input      [31:0] stvec,

    // 外部通信参数
    input             i_uncore_request_busy,
    input             i_uncore_respond_access_fault,
    input             i_uncore_respond_page_fault,
    input             i_uncore_respond_valid,
    input      [31:0] i_uncore_respond_data,
    output            i_uncore_request_valid,
    output     [29:0] i_uncore_request_vaddr,

    // 旁路参数
    input      [31:0] id_jump_addr,
    input      [31:0] m2_jump_addr, // 同时负责 trap, ret, jump

    // 流水线参数
    output reg        id_instr_access_fault,
    output reg        id_instr_page_fault,
    output reg        id_is_instr,
    output reg [31:0] id_instr,
    output reg [31:0] id_pc,
    output reg [31:0] id_pcplus
);

// #region FIFO
reg pop;
wire instr0_valid = read_pos != res_write_pos && !lock;
wire [31:0] instr0 = instr[read_pos[1:0]];
wire instr1_valid = instr0_valid && read_pos + 3'h1 != res_write_pos && !lock;
wire [31:0] instr1 = instr[read_pos[1:0] + 2'h1];
// 组合逻辑接口


reg [29:0] pre_pc;

reg [2:0] read_pos;
reg [2:0] pre_write_pos;
reg [2:0] res_write_pos;

reg lock;

reg [29:0] pc1   [3:0];
reg        af    [3:0];
reg        pf    [3:0];
reg [31:0] instr [3:0];

assign i_uncore_request_valid = (pre_write_pos[2] == read_pos[2] ||
                                pre_write_pos[1:0] != read_pos[1:0]) && !flush && !i_uncore_request_busy;

assign i_uncore_request_vaddr = pre_pc;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pre_pc        <= 30'h0;
        pre_write_pos <= 3'h0;
        lock          <= 1'h0;
        read_pos      <= 3'h0;
        res_write_pos <= 3'h0;
    end
    else begin
        if (i_uncore_request_valid) begin
            pc1[pre_write_pos[1:0]] <= pre_pc;
            pre_pc <= pre_pc + 30'h1;
        end
        if (i_uncore_respond_valid) begin
            af[res_write_pos[1:0]] <= i_uncore_respond_access_fault;
            pf[res_write_pos[1:0]] <= i_uncore_respond_page_fault;
            instr[res_write_pos[1:0]] <= i_uncore_respond_data;
            res_write_pos <= res_write_pos + 3'h1;
            if (res_write_pos + 3'h1 == read_pos) begin
                lock <= 1'h0;
            end
        end
        if (flush) begin
            // pre_pc <= newpc;
            lock <= 1'h1;
            read_pos <= pre_write_pos;
        end
        else if (!lock && pop) begin
            read_pos <= read_pos + 3'h1;
        end
    end
end
// #endregion


reg [30:0] pc;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 31'h0;
    end
    else begin
        
    end
end

always @(*) begin
    if (instr0_valid) begin
        if (!pc[0]) begin
            pop                   = 1'h1;
            id_instr_access_fault = 1'h0;
            id_instr_page_fault   = 1'h0;
            id_is_instr           = 1'h0;
            id_instr              = 32'h0;
            id_pc                 = 32'h0;
            id_pcplus             = 32'h0;
        end
        else begin
            if (instr[read_pos[1:0]][1:0] != 2'h3) begin
                pop                   = 1'h1;
            end
            else begin
                if (instr1_valid) begin
                    pop                   = 1'h1;
                end
                else begin
                    pop                   = 1'h0;
                end
            end
        end
    end
    else begin
        pop                   = 1'h0;
        id_instr_access_fault = 1'h0;
        id_instr_page_fault   = 1'h0;
        id_is_instr           = 1'h0;
        id_instr              = 32'h0;
        id_pc                 = 32'h0;
        id_pcplus             = 32'h0;
    end
end

endmodule


