# (fab) — top-level Makefile
# Generates Verilog from Lisp, then builds bitstream.
#
# Usage:
#   make DESIGN=examples/01-uart-sender/uart-sender.lisp
#   make DESIGN=examples/01-uart-sender/uart-sender.lisp sim
#   make DESIGN=examples/01-uart-sender/uart-sender.lisp load
#   make clean

BOARD    ?= tangnano9k
BOARD_USB ?= tangnano9k
DESIGN   ?=
BUILD     = build

# Bitstream name from filename: foo.lisp → foo
TOP_L     = $(basename $(notdir $(DESIGN)))

# Verilog module name: foo → FOO, foo-bar → FOO_BAR
TOP_V     = $(subst -,_,$(shell echo $(TOP_L) | tr a-z A-Z))

# Auto-detect TB: look for tb.lisp next to DESIGN
TB_FILE   = $(dir $(DESIGN))tb.lisp
TB_EXISTS = $(wildcard $(TB_FILE))

.PHONY: all fab sim load clean

all: fab
	$(MAKE) -C boards/$(BOARD) TOP=$(TOP_L)

fab: $(BUILD)/$(TOP_V).v

$(BUILD)/$(TOP_V).v: $(DESIGN) src/*.lisp fab.asd
	sbcl --noinform --non-interactive \
	  --eval '(require :asdf)' \
	  --eval '(asdf:load-system :fab)' \
	  --eval '(load "$(DESIGN)")' \
	  $(if $(TB_EXISTS),--eval '(load "$(TB_FILE)")',)

# Simulate
sim: fab
	iverilog -o $(BUILD)/sim_tb.vvp $(BUILD)/$(TOP_V).v $(BUILD)/TB_$(TOP_V).v
	vvp $(BUILD)/sim_tb.vvp

# Flash to board
load: fab
	$(MAKE) -C boards/$(BOARD) TOP=$(TOP_L)
	openFPGALoader -b $(BOARD_USB) $(BUILD)/$(TOP_L).fs -f

clean:
	rm -rf $(BUILD)
	$(MAKE) -C boards/$(BOARD) clean
