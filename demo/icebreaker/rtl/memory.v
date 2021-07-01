/*
 *
 *  Copyright (C) 2021  Cristian Balint <cristian dot balint at gmail dot com>
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

//
// ICE40 UP5K
// 4 x 8kB SRAM blocks
// 4 x 16bit SRAM width
// 64 bit data path

module data_mem (
    input clk,
    input [3:0] wen,
    input [16:0] addr,
    input [31:0] wdata,
    output [63:0] rdata
);
    (* keep *)
    SB_SPRAM256KA ram00 (
        .ADDRESS(addr[16:3]),
        .DATAIN(wdata[15:0]),
        .MASKWREN({wen[1], wen[1], wen[0], wen[0]}),
        .WREN(wen[1]|wen[0]),
        .CHIPSELECT(!addr[2]),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata[15:0])
    );

    (* keep *)
    SB_SPRAM256KA ram01 (
        .ADDRESS(addr[16:3]),
        .DATAIN(wdata[31:16]),
        .MASKWREN({wen[3], wen[3], wen[2], wen[2]}),
        .WREN(wen[3]|wen[2]),
        .CHIPSELECT(!addr[2]),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata[31:16])
    );

    (* keep *)
    SB_SPRAM256KA ram10 (
        .ADDRESS(addr[16:3]),
        .DATAIN(wdata[15:0]),
        .MASKWREN({wen[1], wen[1], wen[0], wen[0]}),
        .WREN(wen[1]|wen[0]),
        .CHIPSELECT(addr[2]),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata[47:32])
    );

    (* keep *)
    SB_SPRAM256KA ram11 (
        .ADDRESS(addr[16:3]),
        .DATAIN(wdata[31:16]),
        .MASKWREN({wen[3], wen[3], wen[2], wen[2]}),
        .WREN(wen[3]|wen[2]),
        .CHIPSELECT(addr[2]),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata[63:48])
    );
endmodule

//
// ICE40 UP5K
// 8 x 1kB BRAM blocks
// 8 x 16bit BRAM width
// 128 bit data path

module coef_mem (
    input  clk,
    input  [3:0]  wen,
    input  [14:0] addr,
    input  [31:0] wdata,
    output [127:0] rdata
);
    wire ren = |(!wen);
    wire wlo = |wen[1:0];
    wire whi = |wen[3:2];
    wire [15:0] mlo = {{8{!wen[1]}},{8{!wen[0]}}};
    wire [15:0] mhi = {{8{!wen[3]}},{8{!wen[2]}}};

    (* keep *)
    SB_RAM40_4K bram00 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[15:0] ),
        .WE    (wlo & !addr[3] & !addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mlo),
        .WDATA (wdata[15:0] )
    );

    (* keep *)
    SB_RAM40_4K bram01 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[31:16] ),
        .WE    (whi & !addr[3] & !addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mhi),
        .WDATA (wdata[31:16] )
    );

    (* keep *)
    SB_RAM40_4K bram02 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[47:32] ),
        .WE    (wlo & !addr[3] & addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mlo),
        .WDATA (wdata[15:0] )
    );

    (* keep *)
    SB_RAM40_4K bram03 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[63:48] ),
        .WE    (whi & !addr[3] & addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mhi),
        .WDATA (wdata[31:16] )
    );

    (* keep *)
    SB_RAM40_4K bram04 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[79:64] ),
        .WE    (wlo & addr[3] & !addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mlo),
        .WDATA (wdata[15:0] )
    );

    (* keep *)
    SB_RAM40_4K bram05 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[95:80] ),
        .WE    (whi & addr[3] & !addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mhi),
        .WDATA (wdata[31:16] )
    );

    (* keep *)
    SB_RAM40_4K bram06 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[111:96] ),
        .WE    (wlo & addr[3] & addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mlo),
        .WDATA (wdata[15:0] )
    );

    (* keep *)
    SB_RAM40_4K bram07 (
        .RE    (ren),
        .RCLK  (clk         ),
        .RCLKE (1'b1        ),
        .RADDR (addr[14:4]  ),
        .RDATA (rdata[127:112] ),
        .WE    (whi & addr[3] & addr[2]),
        .WCLK  (clk         ),
        .WCLKE (1'b1        ),
        .WADDR (addr[14:4]  ),
        .MASK  (mhi),
        .WDATA (wdata[31:16] )
    );

endmodule
