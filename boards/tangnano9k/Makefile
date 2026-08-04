# Tang Nano 9K Makefile for (fab)
# Uses yosys + yowasp-nextpnr-gowin + gowin_pack (Apycula)

export PATH := $(HOME)/.local/bin:$(PATH)

DEVICE   = GW1NR-LV9QN88PC6/I5
FAMILY   = GW1N-9C
TOP      ?=
BUILD    = ../../build

# Verilog module name uses underscores: uart-sender → UART_SENDER
TOP_V    = $(subst -,_,$(shell echo $(TOP) | tr a-z A-Z))

.PHONY: all clean

all: $(BUILD)/$(TOP).fs

$(BUILD)/$(TOP).json: $(BUILD)/$(TOP_V).v $(BUILD)/$(TOP_V).cst
	yosys -p "read_verilog $(BUILD)/$(TOP_V).v; synth_gowin -json $@ -top $(TOP_V)"

$(BUILD)/$(TOP)_pnr.json: $(BUILD)/$(TOP).json $(BUILD)/$(TOP_V).cst
	yowasp-nextpnr-gowin --device $(DEVICE) --family $(FAMILY) --cst $(BUILD)/$(TOP_V).cst --json $< --write $@

$(BUILD)/$(TOP).fs: $(BUILD)/$(TOP)_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

clean:
	rm -f $(BUILD)/$(TOP).json $(BUILD)/$(TOP)_pnr.json $(BUILD)/$(TOP).fs $(BUILD)/$(TOP_V).cst
