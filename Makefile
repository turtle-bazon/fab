# (fab) — top-level Makefile
#
# Usage:
#   make build                    # build fab binary
#   make DESIGN=examples/...      # generate HDL only
#   make DESIGN=examples/... BOARD=tangnano9k  # generate + compile to bitstream
#   make clean

LISP    ?= sbcl
BOARD    ?= tangnano9k
DESIGN   ?=
BUILD     = build

# Board binding file: $(dir DESIGN)/$(BOARD).lisp by default
BOARD_BINDING = $(dir $(DESIGN))$(BOARD).lisp

# Bitstream name from filename: foo.lisp → foo
TOP_L     = $(basename $(notdir $(DESIGN)))

# Verilog module name: foo → FOO, foo-bar → FOO_BAR
TOP_V     = $(subst -,_,$(shell echo $(TOP_L) | tr a-z A-Z))

# Auto-detect TB: look for tb.lisp next to DESIGN
TB_FILE   = $(dir $(DESIGN))tb.lisp
TB_EXISTS = $(wildcard $(TB_FILE))

.PHONY: all verilog sim load build clean

# Default: generate Verilog if DESIGN is set, compile if BOARD is also set
all: verilog

# Generate HDL only
verilog: $(BUILD)/$(TOP_V).v

$(BUILD)/$(TOP_V).v: $(DESIGN) src/*.lisp fab.asd boards/$(BOARD)/$(BOARD).lisp $(BOARD_BINDING)
	mkdir -p $(BUILD)
	sbcl --noinform --non-interactive \
	  --eval '(require :asdf)' \
	  --eval '(asdf:load-system :fab)' \
	  --eval '(load "boards/$(BOARD)/$(BOARD).lisp")' \
	  --eval '(load "$(DESIGN)")' \
	  --eval '(load "$(BOARD_BINDING)")' \
	  $(if $(TB_EXISTS),--eval '(load "$(TB_FILE)")',)

# Generate + compile to bitstream (uses fab binary)
compile: $(BUILD)/$(TOP_L).fs

$(BUILD)/$(TOP_L).fs: $(DESIGN) src/*.lisp fab.asd boards/$(BOARD)/$(BOARD).lisp $(BOARD_BINDING) $(BUILD)/fab $(BUILD)/$(TOP_V).v
	$(BUILD)/fab --board-dir boards --board $(BOARD) -o $(BUILD) $(DESIGN)

# Build the fab binary
build: $(BUILD)/fab

$(BUILD)/fab: src/*.lisp fab.asd
	$(LISP) --non-interactive \
	  --eval '(require :asdf)' \
	  --eval '(asdf:load-system :fab)' \
	  --eval '(ensure-directories-exist #p"$(BUILD)/fab")' \
	  --eval '(asdf:make "fab")'

# Simulate
sim: verilog
	iverilog -o $(BUILD)/sim_tb.vvp $(BUILD)/$(TOP_V).v $(BUILD)/TB_$(TOP_V).v
	vvp $(BUILD)/sim_tb.vvp

# Flash to board
load: compile
	openFPGALoader -b $(BOARD) $(BUILD)/$(TOP_L).fs -f

clean:
	rm -rf $(BUILD)
