# cocotb Makefile for echo_8051 UVM verification
SIM ?= icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = echo_8051_top

# RTL sources
VERILOG_SOURCES = \
    $(PWD)/../rtl/alu.v \
    $(PWD)/../rtl/psw.v \
    $(PWD)/../rtl/reg_file.v \
    $(PWD)/../rtl/iram.v \
    $(PWD)/../rtl/prom.v \
    $(PWD)/../rtl/sfr_block.v \
    $(PWD)/../rtl/timer.v \
    $(PWD)/../rtl/uart.v \
    $(PWD)/../rtl/intc.v \
    $(PWD)/../rtl/io_ports.v \
    $(PWD)/../rtl/cpu_core.v \
    $(PWD)/../rtl/echo_8051_top.v

# cocotb test module
MODULE = test_isa

# Waveforms
PLUSARGS += -fst
export COCOTB_RESOLVE_TRIGGER = icarus
