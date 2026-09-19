`timescale 1ns / 1ns

module system_bus (
    input             clk,
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
    output reg [31:0] respond_data_instr
);

reg [7:0] mem [4095:0];

integer i;
integer fd;
integer r;
initial begin
    for (i = 0; i < 4096; i = i + 1)
        mem[i] = 8'h0;
    fd = $fopen("build/sim_test.bin", "rb");
    if(fd == 0) begin
        $display("ERROR: cannot open build/sim_test.bin");
        $finish;
    end
    r = $fread(mem, fd);
    $fclose(fd);
end

reg request_valid_data_reg;
reg request_valid_instr_reg;
reg request_write_data_reg;
reg [3:0] request_en_data_reg;
reg [31:0] request_addr_data_reg;
reg [31:0] request_addr_instr_reg;
reg [31:0] request_data_data_reg;

initial begin
    request_valid_data_reg = 1'h0;
    request_valid_instr_reg = 1'h0;
    request_write_data_reg = 1'h0;
    request_en_data_reg = 4'h0;
    request_addr_data_reg = 32'h0;
    request_addr_instr_reg = 32'h0;
    request_data_data_reg = 32'h0;
    respond_valid_instr = 1'h0;
    respond_fault_instr = 1'h0;
    respond_data_instr = 32'h0;
    respond_valid_data = 1'h0;
    respond_fault_data = 1'h0;
    respond_data_data = 32'h0;
end

always @(posedge clk) begin
    request_valid_data_reg <= request_valid_data;
    request_valid_instr_reg <= request_valid_instr;
    request_write_data_reg <= request_write_data;
    request_en_data_reg <= request_en_data;
    request_addr_data_reg <= request_addr_data;
    request_addr_instr_reg <= request_addr_instr;
    request_data_data_reg <= request_data_data;
end

always @(posedge clk) begin
    respond_valid_instr <= request_valid_instr_reg;
    respond_fault_instr <= request_valid_instr_reg ?
                            request_addr_instr_reg[1:0] != 2'h0 || request_addr_instr_reg[31:12] != 20'h0 :
                            1'h0;
    respond_data_instr <= request_valid_instr_reg && !respond_fault_instr ?
                            {mem[{request_addr_instr_reg[31:2], 2'h3}],
                            mem[{request_addr_instr_reg[31:2], 2'h2}],
                            mem[{request_addr_instr_reg[31:2], 2'h1}],
                            mem[{request_addr_instr_reg[31:2], 2'h0}]} :
                            32'h13;
end

always @(posedge clk) begin
    respond_valid_data <= request_valid_data_reg;
    respond_fault_data <= request_valid_data_reg ? request_addr_data_reg[1:0] != 2'h0 || request_addr_data_reg[31:12] != 20'h0 : 1'h0;
    respond_data_data <= request_valid_data_reg && !request_write_data ?
                            {mem[{request_addr_data_reg[31:2], 2'h3}],
                            mem[{request_addr_data_reg[31:2], 2'h2}],
                            mem[{request_addr_data_reg[31:2], 2'h1}],
                            mem[{request_addr_data_reg[31:2], 2'h0}]} :
                            32'h0;
end

always @(posedge clk) begin
    if (request_valid_data_reg && request_write_data_reg &&
        request_addr_data_reg[1:0] == 2'h0 && request_addr_data_reg[31:12] == 20'h0) begin
        if (request_addr_data_reg == 32'hffc &&
            (request_en_data_reg[0] || request_en_data_reg[1] ||
            request_en_data_reg[2] || request_en_data_reg[3])) begin
            $write("%c", request_data_data_reg[7:0]);
        end
        if (request_en_data_reg[0]) begin
            mem[{request_addr_data_reg[31:2], 2'h0}] <= request_data_data_reg[7:0];
        end
        if (request_en_data_reg[1]) begin
            mem[{request_addr_data_reg[31:2], 2'h1}] <= request_data_data_reg[15:8];
        end
        if (request_en_data_reg[2]) begin
            mem[{request_addr_data_reg[31:2], 2'h2}] <= request_data_data_reg[23:16];
        end
        if (request_en_data_reg[3]) begin
            mem[{request_addr_data_reg[31:2], 2'h3}] <= request_data_data_reg[31:24];
        end
    end
end

endmodule
