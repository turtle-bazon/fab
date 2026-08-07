# (fab) — top-level Makefile
#
# Usage:
#   make build                    # build fab binary
#   make DESIGN=examples/...      # generate + synthesize
#   make clean

LISP    ?= sbcl
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

.PHONY: all fab sim load build clean

all: fab
	./fab-board $(BOARD) TOP=$(TOP_L) BUILD=$(BUILD)

fab: $(BUILD)/$(TOP_V).v

$(BUILD)/$(TOP_V).v: $(DESIGN) src/*.lisp fab.asd boards/$(BOARD)/$(BOARD).lisp
	mkdir -p $(BUILD)
	sbcl --noinform --non-interactive \
	  --eval '(require :asdf)' \
	  --eval '(asdf:load-system :fab)' \
	  --eval '(load "boards/$(BOARD)/$(BOARD).lisp")' \
	  --eval '(load "$(DESIGN)")' \
	  $(if $(TB_EXISTS),--eval '(load "$(TB_FILE)")',)

# Build the fab binary
build: $(BUILD)/fab

$(BUILD)/fab: src/*.lisp fab.asd build.lisp
	mkdir -p $(BUILD)/fab
	$(LISP) --non-interactive --load build.lisp

# Simulate
sim: fab
	iverilog -o $(BUILD)/sim_tb.vvp $(BUILD)/$(TOP_V).v $(BUILD)/TB_$(TOP_V).v
	vvp $(BUILD)/sim_tb.vvp

# Flash to board
load: fab
	./fab-board $(BOARD) TOP=$(TOP_L) BUILD=$(BUILD)
	openFPGALoader -b $(BOARD_USB) $(BUILD)/$(TOP_L).fs -f

clean:
	rm -rf $(BUILD)
	./fab-board $(BOARD) clean BUILD=$(BUILD)
