// C++ ISS trace generator — same format as Python crossval_iss.py
// Build: g++ -std=c++17 -I../model/cpp/include -o crossval_cpp \
//        scripts/crossval_cpp.cpp ../model/cpp/src/echo_8051.cpp

#include "echo_8051.h"
#include <cstdio>
#include <cstdint>

int main() {
    echo_8051::Echo8051 cpu(4096);
    cpu.reset();

    // Same test program as crossval_iss.py
    uint8_t prog[] = {
        0x74,0x42, 0x78,0x55, 0x79,0x33, 0xE8, 0x24,0x20, 0xC3,
        0x94,0x25, 0x54,0x0F, 0x44,0xAA, 0x64,0x55, 0x04, 0x14,
        0x04, 0x04, 0x04, 0xC4, 0xF4, 0xE4, 0x74,0x0A, 0x75,0xF0,0x06,
        0xA4, 0xF5,0x90, 0x74,0x0F, 0x75,0xF0,0x04, 0x84, 0xF5,0xA0,
        0x78,0x03, 0xE4, 0x04, 0xD8,0xFD, 0xF5,0xB0,
        0xC0,0xE0, 0xE4, 0xD0,0xE0, 0xF5,0x80,
        0xD3, 0xC3, 0xB3,
        0x80,0xFE
    };
    cpu.load_bytes(prog, sizeof(prog));

    printf("# C++ ISS instruction trace\n");
    printf("# format: INSTR_NUM|PC|ACC|PSW|SP\n");

    int count = 0;
    uint16_t prev_pc = 0xFFFF;
    int same_pc_count = 0;

    while (count < 200) {
        prev_pc = cpu.get_pc();
        cpu.step();
        count++;

        auto s = cpu.get_state();
        printf("%d|%04X|%02X|%02X|%02X|\n",
               count, s.pc, s.acc, s.psw, s.sp);

        // Detect SJMP $ loop
        if (prev_pc == s.pc) {
            same_pc_count++;
            if (same_pc_count > 3) break;
        } else {
            same_pc_count = 0;
        }
    }

    printf("# Total: %d instructions\n", count);
    return 0;
}
