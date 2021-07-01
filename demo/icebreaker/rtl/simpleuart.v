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

module ctrlsoc_rxtx (
    input             clk,
    input             resetn,
    input             rx,
    output            tx,

    input             mem_wvalid,
    input      [31:0] mem_wdata,
    input             mem_rvalid,
    output reg [31:0] mem_rdata,
    output reg        mem_ready
);
    localparam [7:0] clkdiv_cnt_steps = 175; // 20Mhz

    reg [7:0] clkdiv_cnt = 0;
    reg clkdiv_pulse = 0;

    always @(posedge clk) begin
        clkdiv_cnt <= clkdiv_pulse ? 0 : clkdiv_cnt + 1;
        clkdiv_pulse <= clkdiv_cnt == (clkdiv_cnt_steps - 2);
    end

    reg [7:0] recv_byte;
    reg [7:0] recv_cnt;
    reg [3:0] recv_state;
    reg recv_valid;

    reg rxq;
    reg this_rx;
    reg last_rx;

    always @(posedge clk) begin
        rxq <= rx;
        this_rx <= rxq;
        last_rx <= this_rx;
        recv_cnt <= recv_cnt - |recv_cnt;
        recv_valid <= 0;

        case (recv_state)
            0: begin
                if (last_rx && !this_rx) begin
                    recv_cnt <= clkdiv_cnt_steps / 2;
                    recv_state <= 1;
                end
            end
            10: begin
                if (!recv_cnt) begin
                    recv_valid <= 1;
                    recv_state <= 0;
                end
            end
            default: begin
                if (!recv_cnt) begin
                    recv_cnt <= clkdiv_cnt_steps;
                    recv_byte <= {last_rx, recv_byte[7:1]};
                    recv_state <= recv_state + 1;
                end
            end
        endcase

        if (!resetn) begin
            recv_state <= 0;
            recv_valid <= 0;
        end
    end

    reg [31:0] rbuf;
    reg [3:0] rbuf_valid;

    reg [8:0] sbuf;
    reg [3:0] sbuf_cnt;

    assign tx = sbuf[0];

    always @(posedge clk) begin
        mem_rdata <= 'bx;
        mem_ready <= 0;

        if (recv_valid) begin
            if (!rbuf_valid[0])
                rbuf[7:0] <= recv_byte;
            else if (!rbuf_valid[1])
                rbuf[15:8] <= recv_byte;
            else if (!rbuf_valid[2])
                rbuf[23:16] <= recv_byte;
            else if (!rbuf_valid[3])
                rbuf[31:24] <= recv_byte;
            rbuf_valid <= {rbuf_valid, 1'b1};
        end else
        if (mem_rvalid && !mem_ready) begin
            rbuf <= rbuf >> 8;
            rbuf_valid <= rbuf_valid >> 1;
            mem_rdata <= rbuf[7:0] | {32{!rbuf_valid[0]}};
            mem_ready <= 1;
        end

        if (mem_wvalid && !mem_ready) begin
            if (clkdiv_pulse) begin
                if (!sbuf_cnt) begin
                    sbuf <= {mem_wdata[7:0], 1'b0};
                    sbuf_cnt <= 9;
                end else begin
                    sbuf <= {1'b1, sbuf[8:1]};
                    sbuf_cnt <= sbuf_cnt - 1;
                    mem_ready <= sbuf_cnt == 1;
                end
            end
        end

        if (!resetn) begin
            rbuf_valid <= 0;
            sbuf_cnt <= 0;
            sbuf <= -1;
            mem_ready <= 0;
        end
    end
endmodule
