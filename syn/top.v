`timescale 1ns / 1ns

// 板级顶层：PLL + 复位 + CPU 子系统（core/uncore/device/ROM + sdram_ctr）
//
//   25 MHz 晶振 --PLL--> clk_sys 50 MHz（逻辑）
//                    \--> CLKOS 50 MHz/90° --ODDRX1F--> sdram_clk（送 SDRAM 器件）
//
// 上电：CPU 直接从固定 ROM（0~4K）取指执行，不加载 SDRAM，
//       复位放开后程序立即开始跑（本程序会往 UART 发数据）。
//
// LED（RGB 均高有效）：
//   led_r 常亮 = boot_done（镜像已加载、CPU 已放开复位）
//   led_g 闪   = CPU 在退休指令
//   led_b 闪   = 有往 UART 写过（加载器诊断字节 / 程序输出都算）
module top (
    input         clk,
    output        led_r,
    output        led_g,
    output        led_b,

    output        sdram_clk,
    output        sdram_cke,
    output        sdram_cs_n,
    output        sdram_ras_n,
    output        sdram_cas_n,
    output        sdram_we_n,
    output [1:0]  sdram_ba,
    output [12:0] sdram_a,
    inout  [15:0] sdram_dq,
    output [1:0]  sdram_dm,

    output        uart_tx,
    input         uart_rx
);

// ---------------------------- 时钟 / PLL / ODDR ----------------------------
wire clk_sys, clk_sdram_ps, locked;
// PLL 实际输出 50 MHz。设计实测最差路径约 20.2ns（~49.5MHz），
// 综合时用 --freq 45 + --timing-allow-fail，允许"略超 50MHz 一点"也出 bit 流。
// 25 MHz（整链已验证跑通）。SDRAM 时钟相位按官方 LiteX target 用 180°：
//   pll.create_clkout(self.cd_sys_ps, sys_clk_freq, phase=180) # Idealy 90° but needs to be increased.
// 50 MHz 下仍有个别镜像行写坏，待进一步查（见 README/AGENTS 说明）。
(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "50" *) (* FREQUENCY_PIN_CLKOS = "50" *)
(* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *)
EHXPLLL #(
    .PLLRST_ENA("DISABLED"), .INTFB_WAKE("DISABLED"), .STDBY_ENABLE("DISABLED"), .DPHASE_SOURCE("DISABLED"),
    .OUTDIVIDER_MUXA("DIVA"), .OUTDIVIDER_MUXB("DIVB"), .OUTDIVIDER_MUXC("DIVC"), .OUTDIVIDER_MUXD("DIVD"),
    .CLKI_DIV(1), .CLKFB_DIV(2),
    .CLKOP_ENABLE("ENABLED"), .CLKOP_DIV(12), .CLKOP_CPHASE(5), .CLKOP_FPHASE(0),
    .CLKOS_ENABLE("ENABLED"), .CLKOS_DIV(12), .CLKOS_CPHASE(11), .CLKOS_FPHASE(0),
    .FEEDBK_PATH("CLKOP")
) pll_i (
    .RST(1'b0), .STDBY(1'b0), .CLKI(clk), .CLKOP(clk_sys), .CLKOS(clk_sdram_ps),
    .CLKFB(clk_sys), .CLKINTFB(), .PHASESEL0(1'b0), .PHASESEL1(1'b0),
    .PHASEDIR(1'b1), .PHASESTEP(1'b1), .PHASELOADREG(1'b1), .PLLWAKESYNC(1'b0), .ENCLKOP(1'b0), .LOCK(locked)
);
ODDRX1F oddr_sdram_clk (.D0(1'b1), .D1(1'b0), .SCLK(clk_sdram_ps), .Q(sdram_clk));

wire rst_n;
rst_gen rst_gen (.clk(clk_sys), .locked(locked), .rst_n(rst_n));

// ------------------------------ CPU 子系统 --------------------------------
wire        boot_done;
wire [1:0]  privilege;
wire [31:0] satp;
wire        dbg_cpu, dbg_vfy, dbg_uart, dbg_blink;

cpu_subsys u_cpu (
    .clk(clk_sys), .rst_n(rst_n),
    .sdram_cke(sdram_cke), .sdram_cs_n(sdram_cs_n), .sdram_ras_n(sdram_ras_n),
    .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_ba(sdram_ba),
    .sdram_dm(sdram_dm), .sdram_a(sdram_a), .sdram_dq(sdram_dq),
    .uart_tx(uart_tx), .uart_rx(uart_rx),
    .boot_done(boot_done), .privilege(privilege), .satp(satp),
    .dbg_cpu(dbg_cpu), .dbg_vfy(dbg_vfy), .dbg_uart(dbg_uart), .dbg_blink(dbg_blink)
);

// -------------------------------- 状态灯 ----------------------------------
// led_r 常亮 = 加载完成（boot_done=1）
// led_b 常亮 = 回读第 0 行完全一致（vfy_ok）
// led_g 闪 nmatch 次（0~8，每格 0.25s）后停 8 格，循环 —— 用来数"回读命中几个半字"
assign led_r = boot_done;
assign led_g = dbg_cpu;
assign led_b = dbg_vfy;   // = 主机->FPGA 收到过字节

endmodule
