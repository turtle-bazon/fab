# Tang Nano 9K Makefile for (fab)
# Uses yosys + yowasp-nextpnr-gowin + gowin_pack (Apycula)
#
# Usage:
#   make TOP=usb-keyboard BOARD=tangnano9k BUILD=../../build
#   make TOP=usb-keyboard BUILD=/tmp/my-project

export PATH := $(HOME)/.local/bin:$(PATH)

DEVICE   = GW1NR-LV9QN88PC6/I5
FAMILY   = GW1N-9C
TOP      ?=
BOARD    ?=
BUILD    ?=

# Verilog module name uses underscores: usb-keyboard → USB_KEYBOARD
TOP_V    = $(subst -,_,$(shell echo $(TOP) | tr a-z A-Z))

# Require BUILD
ifeq ($(BUILD),)
  $(error BUILD is not set. Usage: make TOP=name BOARD=name BUILD=path)
endif

# CST file: if BOARD is set, use TOP_BOARD.cst; else use TOP.cst
ifeq ($(BOARD),)
  CST_FILE = $(BUILD)/$(TOP_V).cst
else
  BOARD_V  = $(subst -,_,$(shell echo $(BOARD) | tr a-z A-Z))
  CST_FILE = $(BUILD)/$(TOP_V)_$(BOARD_V).cst
endif

.PHONY: all clean

all: $(BUILD)/$(TOP).fs

$(BUILD)/$(TOP).json: $(BUILD)/$(TOP_V).v $(CST_FILE)
	yosys -p "read_verilog $(BUILD)/*.v; synth_gowin -json $@ -top $(TOP_V)"

$(BUILD)/$(TOP)_pnr.json: $(BUILD)/$(TOP).json $(CST_FILE)
	yowasp-nextpnr-gowin --device $(DEVICE) --family $(FAMILY) --cst $(CST_FILE) --json $< --write $@

$(BUILD)/$(TOP).fs: $(BUILD)/$(TOP)_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

clean:
	rm -f $(BUILD)/$(TOP).json $(BUILD)/$(TOP)_pnr.json $(BUILD)/$(TOP).fs $(CST_FILE)
