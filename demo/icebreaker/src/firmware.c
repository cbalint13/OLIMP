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

#include <stdint.h>
#include <stdbool.h>

#include "rv32-custom.h"

#define MEM_TOTAL 0x20000 /* 128 KB */

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_uart_data (*(volatile uint32_t*)0x02000008)

// --------------------------------------------------------

void putchar(char c)
{
    if (c == '\n')
        putchar('\r');
    reg_uart_data = c;
}

void print(const char *p)
{
    while (*p)
        putchar(*(p++));
}

void print_hex(uint32_t v, int digits)
{
    for (int i = 7; i >= 0; i--) {
        char c = "0123456789abcdef"[(v >> (4*i)) & 15];
        if (c == '0' && i >= digits) continue;
        putchar(c);
        digits = i;
    }
}

void print_dec(uint32_t v)
{
    if (v >= 1000) {
        print(">=1000");
        return;
    }

    if      (v >= 900) { putchar('9'); v -= 900; }
    else if (v >= 800) { putchar('8'); v -= 800; }
    else if (v >= 700) { putchar('7'); v -= 700; }
    else if (v >= 600) { putchar('6'); v -= 600; }
    else if (v >= 500) { putchar('5'); v -= 500; }
    else if (v >= 400) { putchar('4'); v -= 400; }
    else if (v >= 300) { putchar('3'); v -= 300; }
    else if (v >= 200) { putchar('2'); v -= 200; }
    else if (v >= 100) { putchar('1'); v -= 100; }

    if      (v >= 90) { putchar('9'); v -= 90; }
    else if (v >= 80) { putchar('8'); v -= 80; }
    else if (v >= 70) { putchar('7'); v -= 70; }
    else if (v >= 60) { putchar('6'); v -= 60; }
    else if (v >= 50) { putchar('5'); v -= 50; }
    else if (v >= 40) { putchar('4'); v -= 40; }
    else if (v >= 30) { putchar('3'); v -= 30; }
    else if (v >= 20) { putchar('2'); v -= 20; }
    else if (v >= 10) { putchar('1'); v -= 10; }

    if      (v >= 9) { putchar('9'); v -= 9; }
    else if (v >= 8) { putchar('8'); v -= 8; }
    else if (v >= 7) { putchar('7'); v -= 7; }
    else if (v >= 6) { putchar('6'); v -= 6; }
    else if (v >= 5) { putchar('5'); v -= 5; }
    else if (v >= 4) { putchar('4'); v -= 4; }
    else if (v >= 3) { putchar('3'); v -= 3; }
    else if (v >= 2) { putchar('2'); v -= 2; }
    else if (v >= 1) { putchar('1'); v -= 1; }
    else putchar('0');
}

char getchar_prompt(char *prompt)
{
    int32_t c = -1;

    uint32_t cycles_begin, cycles_now, cycles;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

    if (prompt)
        print(prompt);

    while (c == -1) {
        __asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
        cycles = cycles_now - cycles_begin;
        if (cycles > 12000000) {
            if (prompt)
                print(prompt);
            cycles_begin = cycles_now;
        }
        c = reg_uart_data;
    }

    return c;
}

char getchar()
{
    return getchar_prompt(0);
}

uint32_t xorshift32(uint32_t *state)
{
    /* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;

    return x;
}

void cmd_memtest(uint32_t base_addr, uint32_t end_addr)
{
    int cyc_count = 5;
    int stride = 256;
    uint32_t state;

    volatile uint32_t *base_word = (uint32_t *) base_addr;
    volatile uint8_t *base_byte = (uint8_t *) base_addr;

    print("Running memtest: 0x");
    print_hex(base_addr, 8);
    print(" <> 0x");
    print_hex(base_addr + end_addr, 8);
    print(" ");

    // Word access strided test
    for (int i = 1; i <= cyc_count; i++) {

        state = i;

        for (uint32_t word = 0; word < end_addr/sizeof(uint32_t); word += stride) {
            *(base_word + word) = xorshift32(&state);
        }

        state = i;

        for (uint32_t word = 0; word < end_addr/sizeof(uint32_t); word += stride) {
            if (*(base_word + word) != xorshift32(&state)) {
                print("\n ***FAILED WORD*** at 0x");
                print_hex(base_addr + 4*word, 8);
                print("\n");
                return;
            }
        }

        print(".");
    }

    // Byte access (small test)
    for (int byte = 0; byte < 128; byte++) {
        *(base_byte + byte) = (uint8_t) byte;
    }

    for (int byte = 0; byte < 128; byte++) {
        if (*(base_byte + byte) != (uint8_t) byte) {
            print("\n ***FAILED BYTE*** at 0x");
            print_hex(base_addr + byte, 8);
            print("\n");
            return;
        }
    }

    print(" passed\n");
}

// --------------------------------------------------------


#ifdef ICEBREAKER

void print_reg_bit(int val, const char *name)
{
    for (int i = 0; i < 12; i++) {
        if (*name == 0)
            putchar(' ');
        else
            putchar(*(name++));
    }

    putchar(val ? '1' : '0');
    putchar('\n');
}

#endif

// --------------------------------------------------------

uint32_t cmd_benchmark(bool verbose, uint32_t *instns_p)
{
    uint8_t data[256];
    uint32_t *words = (void*)data;

    uint32_t x32 = 314159265;

    uint32_t cycles_begin, cycles_end;
    uint32_t instns_begin, instns_end;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));
    __asm__ volatile ("rdinstret %0" : "=r"(instns_begin));

    for (int i = 0; i < 20; i++)
    {
        for (int k = 0; k < 256; k++)
        {
            x32 ^= x32 << 13;
            x32 ^= x32 >> 17;
            x32 ^= x32 << 5;
            data[k] = x32;
        }

        for (int k = 0, p = 0; k < 256; k++)
        {
            if (data[k])
                data[p++] = k;
        }

        for (int k = 0, p = 0; k < 64; k++)
        {
            x32 = x32 ^ words[k];
        }
    }

    __asm__ volatile ("rdcycle %0" : "=r"(cycles_end));
    __asm__ volatile ("rdinstret %0" : "=r"(instns_end));

    if (verbose)
    {
        print("Cycles: 0x");
        print_hex(cycles_end - cycles_begin, 8);
        putchar('\n');

        print("Instns: 0x");
        print_hex(instns_end - instns_begin, 8);
        putchar('\n');

        print("Chksum: 0x");
        print_hex(x32, 8);
        putchar('\n');
    }

    if (instns_p)
        *instns_p = instns_end - instns_begin;

    return cycles_end - cycles_begin;
}

uint32_t cmd_benchmark_multiply(bool verbose, uint32_t *instns_p, uint8_t seed)
{
    uint8_t acc = 0;
    uint8_t data[32];
    for (int i = 0; i < 32; i++)
    {
        data[i] = i;
    }

    uint32_t cycles_begin, cycles_end;
    uint32_t instns_begin, instns_end;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));
    __asm__ volatile ("rdinstret %0" : "=r"(instns_begin));

    for (int i = 0; i < 32; i++)
    {
        acc += data[i] * seed;
    }

    __asm__ volatile ("rdcycle %0" : "=r"(cycles_end));
    __asm__ volatile ("rdinstret %0" : "=r"(instns_end));

    if (verbose)
    {
        print("Cycles: 0x");
        print_hex(cycles_end - cycles_begin, 8);
        putchar('\n');

        print("Instns: 0x");
        print_hex(instns_end - instns_begin, 8);
        putchar('\n');

    }

    print("Result: 0x");
    print_hex((uint32_t)acc, 8);
    putchar('\n');

    if (instns_p)
        *instns_p = instns_end - instns_begin;

    return cycles_end - cycles_begin;
}

uint32_t cmd_benchmark_olimp()
{
    // fill data register ( 1*8 octets / 64 bits)
    *(uint32_t*) 0x00010000 = 0x00000003;
    *(uint32_t*) 0x00010004 = 0x00000000;
    *(uint32_t*) 0x00010008 = 0x00000000;
    *(uint32_t*) 0x0001000c = 0x00000000;

    // fill coef register (2*8 octets / 128 bits)
    *(uint32_t*) 0x10000000 = 0x00000002;
    *(uint32_t*) 0x10000004 = 0x00000000;
    *(uint32_t*) 0x10000008 = 0x00000000;
    *(uint32_t*) 0x1000000c = 0x00000000;

    *(uint32_t*) 0x10000010 = 0x00000002;
    *(uint32_t*) 0x10000014 = 0x00000000;
    *(uint32_t*) 0x10000018 = 0x00000000;
    *(uint32_t*) 0x1000001c = 0x00000000;

    print("x31: 0x");
    // pass offset pointers via rs1 & rs2
    asm("li x28, 0x00010000"); // -> rs1 ( 64 bit alignment)
    asm("li x29, 0x00000000"); // -> rs2 (128 bit alignment)

    // X, rd, rs1, rs2, funct
    CUSTOMX_R_R_R(0, 31, 28, 29, 0);

    uint32_t reg;
    asm("mv %0,x31" : "=rm"(reg));

        // display MACC result
    print_hex(reg, 8);
    putchar('\n');

    return 0;
}

void cmd_dump_memory(uint32_t base_addr, const uint32_t len)
{
    for (uint32_t i = 0; i < len; i += 1)
    {
        if (i % (4*8) == 0)
        {
            print("\n0x");
            print_hex(base_addr + i, 8);
            print(":");
        }
        const uint8_t byte = *(uint8_t*) (base_addr + i);
        if (i % 4 == 0)
            print(" ");
        print_hex(byte,2);
    }
    putchar('\n');



    return;
}

// --------------------------------------------------------


#ifdef ICEBREAKER
void cmd_benchmark_all()
{
    uint32_t instns = 0;

    print("default\n");
    print_hex(cmd_benchmark(true, &instns), 8);
    putchar('\n');
}
#endif

void cmd_echo()
{
    print("Return to menu by sending '!'\n\n");
    char c;
    while ((c = getchar()) != '!')
        putchar(c);
}

// --------------------------------------------------------

void main()
{
//    CUSTOMX_R_R_R(0, 0, 0, 0, 0);
//    CUSTOMX_R_R_R(0, 0, 0, 0, 0);
        print("Booting..\n");

        while (getchar_prompt("Press ENTER to continue..\n") != '\r') { /* wait */ }

        print("\n");

        print("VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV\n");
        print("             VVVVVVVVVVVVVVVVVVVVVVVVVVV\n");
        print("                 VVVVVVVVVVVVVVVVVVVVVVV\n");
        print("RRRRRRRRRRR        VVVVVVVVVVVVVVVVVVVVV\n");
        print("RRRRRRRRRRRRRRR      VVVVVVVVVVVVVVVVVVV\n");
        print("RRRRRRRRRRRRRRRR     VVVVVVVVVVVVVVVVVVV\n");
        print("RRRRRRRRRRRRRRRRR     VVVVVVVVVVVVVVVVVV\n");
        print("RRRRRRRRRRRRRRRRR     VVVVVVVVVVVVVVVVV \n");
        print("RRRRRRRRRRRRRRRRR     VVVVVVVVVVVVVVV   \n");
        print("RRRRRRRRRRRRRRRR     VVVVVVVVVVVVVVV    \n");
        print("RRRRRRRRRRRRRR      VVVVVVVVVVVVVVV     \n");
        print("RRR               VVVVVVVVVVVVVVV      R\n");
        print("RRRR           VVVVVVVVVVVVVVVVV     RRR\n");
        print("RRRRR       VVVVVVVVVVVVVVVVVV      RRRR\n");
        print("RRRRRRR      VVVVVVVVVVVVVVVV     RRRRRR\n");
        print("RRRRRRRRR      VVVVVVVVVVVVV     RRRRRRR\n");
        print("RRRRRRRRRR      VVVVVVVVVV      RRRRRRRR\n");
        print("RRRRRRRRRRRR      VVVVVVV     RRRRRRRRRR\n");
        print("RRRRRRRRRRRRRR      VVV      RRRRRRRRRRR\n");
        print("RRRRRRRRRRRRRRR            RRRRRRRRRRRRR\n");
        print("RRRRRRRRRRRRRRRRR         RRRRRRRRRRRRRR\n");

        print("\n");
        print("Total memory: ");
        print_dec(MEM_TOTAL / 1024);
        print(" KiB\n");
        print("\n");

        //cmd_memtest(0, MEM_TOTAL); // test overwrites bss and data memory
        print("\n");

        print("\n");

        while (1)
    {
        print("\n");

        print("Select an action:\n");
        print("\n");
        print("   [c] Run OLIMP benchmark\n");
        print("   [1] Run simple MUL benchmark\n");
        print("   [9] Run simple XOR benchmark\n");
        print("   [0] Benchmark SPI flash access\n");
        print("   [M] Run Memtest\n");
        print("   [D] Dump Memory (WORDS)\n");
        print("   [d] Dump Memory (BYTES)\n");
        print("   [e] Echo UART\n");
        print("\n");

        for (int rep = 10; rep > 0; rep--)
        {
            print("Command> ");
            char cmd = getchar();
            if (cmd > 32 && cmd < 127)
                putchar(cmd);
            print("\n");

            switch (cmd)
            {
            case '1':
                cmd_benchmark_multiply(true, 0, 3);
                break;
            case '9':
                cmd_benchmark(true, 0);
                break;
            case '0':
                cmd_benchmark_all();
                break;
            case 'M':
                cmd_memtest(0x00000000, MEM_TOTAL);
                cmd_memtest(0x10000000, 1024     );
                break;
            case 'D':
                cmd_dump_memory(0x00010000, 256);
                cmd_dump_memory(0x10000000, 1024);
                break;
            case 'e':
                cmd_echo();
                break;
            case 'c':
                cmd_benchmark_olimp();
                break;
            default:
                continue;
            }

            break;
        }
    }

}
