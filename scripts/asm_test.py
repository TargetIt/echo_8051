#!/usr/bin/env python3
"""8051 test assembler — generate machine code for regression tests."""

# Opcode map for common instructions
OPCODES = {
    # MOV
    'MOV A,#': 0x74, 'MOV A,d': 0xE5, 'MOV d,A': 0xF5, 'MOV d,#': 0x75,
    'MOV A,R0': 0xE8, 'MOV A,R1': 0xE9, 'MOV A,R2': 0xEA, 'MOV A,R3': 0xEB,
    'MOV A,R4': 0xEC, 'MOV A,R5': 0xED, 'MOV A,R6': 0xEE, 'MOV A,R7': 0xEF,
    'MOV R0,A': 0xF8, 'MOV R1,A': 0xF9, 'MOV R2,A': 0xFA, 'MOV R3,A': 0xFB,
    'MOV R4,A': 0xFC, 'MOV R5,A': 0xFD, 'MOV R6,A': 0xFE, 'MOV R7,A': 0xFF,
    'MOV R0,#': 0x78, 'MOV R1,#': 0x79, 'MOV R2,#': 0x7A, 'MOV R3,#': 0x7B,
    'MOV R4,#': 0x7C, 'MOV R5,#': 0x7D, 'MOV R6,#': 0x7E, 'MOV R7,#': 0x7F,
    'MOV A,@R0': 0xE6, 'MOV A,@R1': 0xE7,
    'MOV @R0,A': 0xF6, 'MOV @R1,A': 0xF7,
    'MOV @R0,#': 0x76, 'MOV @R1,#': 0x77,
    'MOV DPTR,#': 0x90,
    # ALU
    'ADD A,#': 0x24, 'ADD A,R0': 0x28, 'ADD A,R1': 0x29, 'ADD A,R2': 0x2A,
    'ADD A,R3': 0x2B, 'ADD A,R4': 0x2C, 'ADD A,R5': 0x2D, 'ADD A,R6': 0x2E, 'ADD A,R7': 0x2F,
    'ADDC A,#': 0x34, 'SUBB A,#': 0x94,
    'ANL A,#': 0x54, 'ORL A,#': 0x44, 'XRL A,#': 0x64,
    'INC A': 0x04, 'DEC A': 0x14,
    'INC R0': 0x08, 'INC R1': 0x09, 'INC R2': 0x0A, 'INC R3': 0x0B,
    'INC R4': 0x0C, 'INC R5': 0x0D, 'INC R6': 0x0E, 'INC R7': 0x0F,
    'DEC R0': 0x18, 'DEC R1': 0x19, 'DEC R2': 0x1A, 'DEC R3': 0x1B,
    'DEC R4': 0x1C, 'DEC R5': 0x1D, 'DEC R6': 0x1E, 'DEC R7': 0x1F,
    # MUL/DIV
    'MUL AB': 0xA4, 'DIV AB': 0x84, 'DA A': 0xD4,
    # Rotate
    'RL A': 0x23, 'RLC A': 0x33, 'RR A': 0x03, 'RRC A': 0x13,
    'SWAP A': 0xC4,
    # Bit
    'SETB C': 0xD3, 'CLR C': 0xC3, 'CPL C': 0xB3,
    'CLR A': 0xE4, 'CPL A': 0xF4,
    # Stack
    'PUSH d': 0xC0, 'POP d': 0xD0,
    # Jump
    'SJMP $': (0x80, 0xFE),
    'NOP': 0x00, 'RET': 0x22, 'RETI': 0x32,
    # INC DPTR
    'INC DPTR': 0xA3,
    'MOVC A,@A+DPTR': 0x93,
}

SFR = {'ACC': 0xE0, 'B': 0xF0, 'PSW': 0xD0, 'SP': 0x81,
       'P0': 0x80, 'P1': 0x90, 'P2': 0xA0, 'P3': 0xB0,
       'DPL': 0x82, 'DPH': 0x83,
       'TCON': 0x88, 'TMOD': 0x89, 'TL0': 0x8A, 'TH0': 0x8C,
       'TL1': 0x8B, 'TH1': 0x8D,
       'SCON': 0x98, 'SBUF': 0x99,
       'IE': 0xA8, 'IP': 0xB8}

def sfr(reg): return SFR.get(reg, 0)

def asm(code: str) -> bytearray:
    """Assemble 8051 code. Each line: LABEL: MNEMONIC ; comment"""
    rom = bytearray(65536)
    addr = 0
    labels = {}

    for line in code.strip().split('\n'):
        line = line.split(';')[0].strip()
        if not line:
            continue
        # Check for label
        if ':' in line:
            label, rest = line.split(':', 1)
            labels[label.strip()] = addr
            line = rest.strip()
            if not line:
                continue

        # Parse mnemonic and operands
        parts = line.replace(',', ' ').split()
        if not parts:
            continue
        mnemonic = parts[0]

        # Handle SJMP with label: 'SJMP label' (PC-relative, 2 bytes)
        if mnemonic == 'SJMP' and len(parts) == 2 and not parts[1].startswith('$'):
            label_name = parts[1]
            # Placeholder: rel byte will be patched later
            rom[addr] = 0x80; addr += 1; rom[addr] = 0x00; addr += 1
            # Store patch info
            if not hasattr(asm, 'patches'):
                asm.patches = []
            asm.patches.append((addr - 1, label_name))
            continue

        # Handle SJMP $ (0x80 0xFE)
        if mnemonic == 'SJMP' and parts[1] == '$':
            rom[addr] = 0x80; addr += 1; rom[addr] = 0xFE; addr += 1
            continue

        # Handle JZ/JNZ/JC/JNC label
        if mnemonic in ('JZ', 'JNZ', 'JC', 'JNC') and len(parts) == 2:
            op = {'JZ': 0x60, 'JNZ': 0x70, 'JC': 0x40, 'JNC': 0x50}[mnemonic]
            rom[addr] = op; addr += 1; rom[addr] = 0x00; addr += 1
            if not hasattr(asm, 'patches'):
                asm.patches = []
            asm.patches.append((addr - 1, parts[1]))
            continue

        # Handle CJNE Rn,#imm,label
        if mnemonic == 'CJNE' and len(parts) == 3:
            rn = int(parts[0][1]) if parts[0].startswith('R') else 0
            op = 0xB8 + rn  # CJNE Rn,#imm,rel
            rom[addr] = op; addr += 1
            rom[addr] = int(parts[1], 16) if parts[1].startswith('0x') else int(parts[1].lstrip('#'))
            addr += 1; rom[addr] = 0x00; addr += 1
            if not hasattr(asm, 'patches'):
                asm.patches = []
            asm.patches.append((addr - 1, parts[2]))
            continue

        # Handle DJNZ Rn,label
        if mnemonic == 'DJNZ' and len(parts) == 2:
            rn = int(parts[0][1]) if parts[0].startswith('R') else 0
            op = 0xD8 + rn
            rom[addr] = op; addr += 1; rom[addr] = 0x00; addr += 1
            if not hasattr(asm, 'patches'):
                asm.patches = []
            asm.patches.append((addr - 1, parts[1]))
            continue

        # Handle LCALL label (3 bytes: 0x12 addr16)
        if mnemonic == 'LCALL' and len(parts) == 2:
            rom[addr] = 0x12; addr += 1; rom[addr] = 0x00; addr += 1; rom[addr] = 0x00; addr += 1
            if not hasattr(asm, 'patches'):
                asm.patches = []
            asm.patches.append((addr - 2, parts[1], True))  # True = 16-bit addr
            continue

        # Standard opcode lookup
        key = f"{mnemonic} {parts[1]}" if len(parts) > 1 else mnemonic
        if key not in OPCODES:
            # Try variations
            for k, v in OPCODES.items():
                if k.startswith(key):
                    key = k
                    break

        if key in OPCODES:
            op = OPCODES[key]
            if isinstance(op, tuple):
                for b in op:
                    rom[addr] = b; addr += 1
            else:
                rom[addr] = op; addr += 1

            # Handle immediate operand (#xx or #0xXX)
            if key.endswith('#') and len(parts) > 1:
                val_str = parts[1] if len(parts) == 2 else parts[2] if len(parts) == 3 else '0'
                if val_str.startswith('0x') or val_str.startswith('#'):
                    val_str = val_str.lstrip('#')
                val = int(val_str, 16) if val_str.startswith('0x') or any(c in 'abcdef' for c in val_str.lower()) else int(val_str)
                rom[addr] = val; addr += 1

            # Handle direct address operand (d:xx)
            elif key.endswith('d') and len(parts) > 1:
                reg_name = parts[1]
                rom[addr] = sfr(reg_name) if reg_name in SFR else int(reg_name, 16)
                addr += 1

            # Handle DPTR,#imm16
            elif mnemonic == 'MOV' and parts[1] == 'DPTR,#':
                dptr_val = int(parts[2].lstrip('#'), 16)
                rom[addr] = (dptr_val >> 8) & 0xFF; addr += 1
                rom[addr] = dptr_val & 0xFF; addr += 1
        else:
            raise ValueError(f"Unknown instruction: {line} (key={key})")

    # Apply patches (PC-relative offsets)
    if hasattr(asm, 'patches'):
        for patch in asm.patches:
            if len(patch) == 3:  # 16-bit addr (LCALL)
                patch_addr, label_name, _ = patch
                target = labels[label_name]
                rom[patch_addr + 1] = (target >> 8) & 0xFF
                rom[patch_addr + 2] = target & 0xFF
            else:  # 8-bit rel
                patch_addr, label_name = patch
                target = labels[label_name]
                rel = target - (patch_addr + 1)
                rom[patch_addr] = rel & 0xFF
        asm.patches = []

    return bytes(rom[:addr])


# ===== Test Programs =====

def test_mov_imm():
    """MOV A,#imm + MOV Rn,#imm"""
    return asm("""
    MOV A,#0x42
    MOV R0,A      ; verify MOV Rn,A
    ; Now check: MOV A,R0 should give 0x42
    MOV A,#0x00
    MOV A,R0
    MOV P1,A      ; P1 = 0x42 if MOV Rn,A and MOV A,Rn work
    SJMP $
    """)

def test_alu_imm():
    """ADD/ADDC/SUBB/ANL/ORL/XRL A,#imm"""
    return asm("""
    MOV A,#0x10
    ADD A,#0x20   ; A = 0x30
    MOV P1,A      ; P1 = 0x30
    MOV A,#0x50
    SUBB A,#0x10  ; A = 0x40 (C=0 initially)
    MOV P2,A      ; P2 = 0x40 (need CLR C before SUBB)
    MOV A,#0x0F
    ANL A,#0xF0   ; A = 0x00
    MOV P3,A      ; P3 = 0x00 (verify ANL masking)
    SJMP $
    """)

def test_mul_div():
    """MUL AB / DIV AB"""
    return asm("""
    MOV A,#0x0A   ; A = 10
    MOV B,#0x06   ; B = 6
    MUL AB        ; A = 0x3C (60), B = 0x00
    MOV P1,A      ; P1 = 60
    MOV A,#0x0F   ; A = 15
    MOV B,#0x04   ; B = 4
    DIV AB        ; A = 3, B = 3
    MOV P2,A      ; P2 = 3
    SJMP $
    """)

def test_push_pop():
    """PUSH / POP"""
    return asm("""
    MOV A,#0x55
    PUSH ACC     ; SP increased, 0x55 on stack
    MOV A,#0x00  ; clear A
    POP ACC      ; A should be 0x55 again
    MOV P1,A     ; P1 = 0x55
    SJMP $
    """)

def test_djnz():
    """DJNZ loop"""
    return asm("""
    MOV R0,#0x05  ; loop counter = 5
loop:
    INC A         ; A = A + 1
    DJNZ R0,loop  ; decrement R0, jump if not zero
    ; After 5 iterations, A = 5
    MOV P1,A      ; P1 = 5
    SJMP $
    """)

def test_jumps():
    """JZ/JNZ/JC/JNC"""
    return asm("""
    MOV A,#0x00
    JZ is_zero    ; should jump (A==0)
    MOV P1,#0xFF  ; ❌ shouldn't reach here
    SJMP $
is_zero:
    MOV A,#0x01
    JNZ not_zero  ; should jump (A!=0)
    MOV P1,#0xFE  ; ❌ shouldn't reach here
    SJMP $
not_zero:
    CLR C
    JNC carry_clr ; should jump (C==0)
    MOV P1,#0xFD  ; ❌ shouldn't reach here
    SJMP $
carry_clr:
    MOV P1,#0x42  ; ✅ all jumps worked
    SJMP $
    """)

def test_bit_ops():
    """SETB/CLR/CPL C"""
    return asm("""
    CLR C
    MOV A,#0x00
    JNC c_is_0    ; C should be 0
    SJMP $
c_is_0:
    SETB C
    JC c_is_1     ; C should be 1
    SJMP $
c_is_1:
    CPL C
    JNC c_toggled ; C should be 0 again
    SJMP $
c_toggled:
    MOV P1,#0x55  ; ✅ all bit ops work
    SJMP $
    """)

def test_lcall_ret():
    """LCALL / RET"""
    return asm("""
    MOV A,#0x00
    LCALL sub     ; call subroutine
    MOV P2,A      ; P2 = return value (0x77)
    SJMP $
sub:
    MOV A,#0x77
    RET
    """)

def test_timer():
    """Timer 0 in mode 1 (16-bit), check overflow"""
    return asm("""
    MOV TMOD,#0x01  ; T0 mode 1 (16-bit timer)
    MOV TH0,#0xFF   ; load high byte
    MOV TL0,#0xF0   ; load low byte → 0xFFF0
    SETB TR0        ; start T0
    JB TF0,t0_ovf   ; wait for overflow? In sim, timer ticks immediately
    ; For RTL simulation, timer ticks once per 12 machine cycles
    ; In ISS, it ticks per instruction. We'll check via the testbench timer_tick.
    MOV P1,#0x00   ; no overflow yet
    SJMP $
t0_ovf:
    MOV P1,#0xAA   ; ✅ Timer overflow occurred
    CLR TF0
    SJMP $
    """)

def test_uart_tx():
    """UART transmit: write to SBUF, wait for TI"""
    return asm("""
    MOV SCON,#0x50 ; mode 1 (8-bit UART), REN=1
    MOV SBUF,#0x41 ; send 'A' = 0x41
    JNB TI,$       ; wait for transmit complete
    CLR TI
    MOV P1,#0x41   ; ✅ UART TX worked
    SJMP $
    """)


def build_test_rom(test_name: str = "all") -> bytes:
    """Build a ROM image with the requested tests."""
    rom = bytearray(65536)
    addr = 0

    tests = {
        'mov_imm': test_mov_imm,
        'alu_imm': test_alu_imm,
        'mul_div': test_mul_div,
        'push_pop': test_push_pop,
        'djnz': test_djnz,
        'jumps': test_jumps,
        'bit_ops': test_bit_ops,
        'lcall_ret': test_lcall_ret,
        'timer': test_timer,
        'uart_tx': test_uart_tx,
    }

    if test_name == 'all':
        for name, fn in tests.items():
            print(f"Building test: {name}")
            prog = fn()
            rom[addr:addr+len(prog)] = prog
            addr += len(prog)
    else:
        prog = tests[test_name]()
        rom[addr:addr+len(prog)] = prog
        addr += len(prog)

    print(f"Total ROM bytes used: {addr}")
    return bytes(rom)


if __name__ == '__main__':
    import sys
    name = sys.argv[1] if len(sys.argv) > 1 else 'all'
    rom = build_test_rom(name)
    # Write to file
    with open('test_prog.hex', 'w') as f:
        for i in range(0, len(rom), 16):
            chunk = rom[i:i+16]
            hex_str = ''.join(f'{b:02X}' for b in chunk)
            # Intel HEX format
            f.write(f":{len(chunk):02X}{i:04X}00{hex_str}{(-sum(chunk)-len(chunk)- (i>>8) - (i&0xFF))&0xFF:02X}\n")
        f.write(":00000001FF\n")
    print(f"Written test_prog.hex ({len(rom)} bytes)")
