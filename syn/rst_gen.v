`timescale 1ns / 1ns

module rst_gen (
    input      clk,
    input      locked,        // PLL LOCK：没锁定前一直复位
    output reg rst_n
);

// 上电：等 PLL 锁定后再数 1024 拍才放开复位（给 SDRAM/时钟留稳定时间）
reg [9:0] t;

initial begin
    t     = 10'h0;
    rst_n = 1'h0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        if (locked) begin
            if (t == 10'h3ff) begin
                rst_n <= 1'h1;
            end
            else begin
                t <= t + 10'h1;
            end
        end
        else begin
            t <= 10'h0;
        end
    end
end

endmodule
