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

`timescale 1 ns / 1 ps

module testbench;
    reg clk;
    always #5 clk = (clk === 1'b0);

    //localparam ser_half_period = 53; // work @12Mhz
    //localparam ser_half_period = 86; // work @20Mhz
    localparam ser_half_period = 175; // work @20Mhz

    event ser_sample;

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        repeat (6) begin
            repeat (50000) @(posedge clk);
            $display("+50000 cycles");
        end
        $finish;
    end

    integer cycle_cnt = 0;

    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
    end

    wire ser_rx;
    wire ser_tx;

    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;
    wire flash_io2;
    wire flash_io3;

    icebreaker #(
        // We limit the amount of memory in simulation
        // in order to avoid reduce simulation time
        // required for intialization of RAM
        .MEM_WORDS(256)
    ) uut (
        .osc12    (clk      ),
        .ser_rx   (ser_rx   ),
        .ser_tx   (ser_tx   ),
        .flash_csb(flash_csb),
        .flash_clk(flash_clk),
        .flash_io0(flash_io0),
        .flash_io1(flash_io1),
        .flash_io2(flash_io2),
        .flash_io3(flash_io3)
    );

    spiflash spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(flash_io2),
        .io3(flash_io3)
    );

    reg [7:0] buffer;

    always begin
        @(negedge ser_tx);

        repeat (ser_half_period) @(posedge clk);
        -> ser_sample; // start bit

        repeat (8) begin
            repeat (ser_half_period) @(posedge clk);
            repeat (ser_half_period) @(posedge clk);
            buffer = {ser_tx, buffer[7:1]};
            -> ser_sample; // data bit
        end

        repeat (ser_half_period) @(posedge clk);
        repeat (ser_half_period) @(posedge clk);
        -> ser_sample; // stop bit

        if (buffer < 32 || buffer >= 127)
            $display("Serial data: %d", buffer);
        else
            $display("Serial data: '%c'", buffer);
    end

endmodule
