/*
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *                2021  Cristian Balint <cristian dot balint at gmail dot com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`ifdef PICOSOC_V
`error "icebreaker.v must be read before picosoc.v!"
`endif

`define PICOSOC_MEM ice40up5k_spram

module icebreaker (
    input  osc12,
    output ser_tx,
    input  ser_rx,
    output flash_csb,
    output flash_clk,
    inout  flash_io0,
    inout  flash_io1,
    inout  flash_io2,
    inout  flash_io3
);

    wire  osc12;
    wire  clk_cpu;
    wire  clk_spi;


`ifdef SYNTHESIS
    // ice40 pll
    SB_PLL40_2F_PAD #(
        .FEEDBACK_PATH("SIMPLE"),
        .PLLOUT_SELECT_PORTA ("GENCLK"),
        .PLLOUT_SELECT_PORTB ("GENCLK_HALF"),
        .DIVR(4'b0000),        // DIVR =  0
        .DIVF(7'b0110100),    // DIVF = 52
        .DIVQ(3'b100),        // DIVQ =  4
        .FILTER_RANGE(3'b001)    // FILTER_RANGE = 1
    ) pll (
        .RESETB        (1'b1),
        .BYPASS        (1'b0),
        .PACKAGEPIN    (osc12),
        .PLLOUTGLOBALA (clk_spi), // 40mhz (39.750)
        .PLLOUTGLOBALB (clk_cpu)  // 20mhz
    );
`else
    // testbench
    div_clk div_two_clk(
        .clk(osc12),
        .div2_clk(clk_cpu)
    );
    assign clk_spi = osc12;
`endif

    parameter integer MEM_WORDS = 32768;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk_cpu) begin
        reset_cnt <= reset_cnt + !resetn;
    end

    wire flash_io0_oe, flash_io0_do, flash_io0_di;
    wire flash_io1_oe, flash_io1_do, flash_io1_di;
    wire flash_io2_oe, flash_io2_do, flash_io2_di;
    wire flash_io3_oe, flash_io3_do, flash_io3_di;

    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP(1'b 0)
    ) flash_io_buf [3:0] (
        .PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
        .OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
        .D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
        .D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
    );

    picosoc #(
        .MEM_WORDS(MEM_WORDS)
    ) soc (
        .clk_cpu      (clk_cpu     ),
        .clk_spi      (clk_spi     ),
        .resetn       (resetn      ),

        .ser_tx       (ser_tx      ),
        .ser_rx       (ser_rx      ),

        .flash_csb    (flash_csb   ),
        .flash_clk    (flash_clk   ),

        .flash_io0_oe (flash_io0_oe),
        .flash_io1_oe (flash_io1_oe),
        .flash_io2_oe (flash_io2_oe),
        .flash_io3_oe (flash_io3_oe),

        .flash_io0_do (flash_io0_do),
        .flash_io1_do (flash_io1_do),
        .flash_io2_do (flash_io2_do),
        .flash_io3_do (flash_io3_do),

        .flash_io0_di (flash_io0_di),
        .flash_io1_di (flash_io1_di),
        .flash_io2_di (flash_io2_di),
        .flash_io3_di (flash_io3_di)
    );
endmodule
