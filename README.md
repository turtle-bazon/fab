# (fab)

A Common Lisp toolchain for digital hardware design. Describe hardware in a language-neutral IR, emit portable Verilog-2001.

## Quick Start

```bash
# Generate Verilog from a design
fab usb-keyboard.lisp

# Generate + compile to FPGA bitstream
fab --board tangnano9k usb-keyboard.lisp
```

## Installation

### Binary

Download or build the `fab` binary:

```bash
# Build from source (requires SBCL + Quicklisp)
git clone git@github.com:turtle-bazon/fab.git
cd fab
make build    # produces build/fab
cp build/fab /usr/local/bin/
```

### FPGA Toolchain (for --board)

```bash
# Yosys (synthesis)
sudo apt install yosys

# nextpnr-himbaechel + gowin_pack (place & route + bitstream)
pip install yowasp-nextpnr-himbaechel-gowin apycula
```

## Usage

```
fab [options] <DESIGN>

Options:
  -o, --output-dir DIR    Output directory (default: build)
  -b, --board-dir DIR     Board search directory (may be repeated)
  --board NAME            Compile with FPGA toolchain after generation
```

### Generate Verilog only

```bash
fab examples/03-usb-keyboard/usb-keyboard.lisp
fab -o rtl/ examples/03-usb-keyboard/usb-keyboard.lisp
```

### Generate + compile to bitstream

```bash
fab --board tangnano9k examples/03-usb-keyboard/usb-keyboard.lisp
```

This runs: `fab` (generate) → `yosys` (synthesize) → `nextpnr` (place & route) → `gowin_pack` (bitstream).

### Custom board search path

```bash
fab -b /usr/share/fab/boards --board tangnano9k design.lisp
```

## Design Files

A design is a `.lisp` file with `(fab)` forms. Design files are **board-agnostic** — pin mappings go in a separate binding file.

```lisp
;; my-design.lisp — board-agnostic design
(in-package :fab)

(fab
 (module my-design
   :ports ((clk :input)
           (led :output))
   :assigns ((led clk))
   :body ()))
```

```lisp
;; tangnano9k.lisp — board binding (in same directory)
(in-package :fab)

(fab (board-target my-design :board :tangnano9k))
```

### Module form

```lisp
(fab
 (module name
   :depends (dep1 dep2)        ;; auto-load dependency modules
   :ports ((port-name direction width :reg) ...)
   :signals ((sig-name :wire width) ...)
   :params ((name value) ...)
   :localparams ((name value) ...)
   :assigns ((lhs rhs) ...)
   :body ((statement ...) ...)))
```

### Board-target form

Maps design ports to physical FPGA pins. Lives in a separate file (e.g., `tangnano9k.lisp`) next to the design:

```lisp
(fab (board-target my-design :board :tangnano9k))
```

The fab binary auto-discovers `<board>.lisp` in the design's directory when `--board` is specified.

## DSL Reference

### Port directions

`:input`, `:output`, `:inout`

### Signals

```lisp
(sig :wire)              ;; 1-bit wire
(sig :wire 8)            ;; 8-bit wire [7:0]
(sig :reg)               ;; 1-bit reg
(sig :reg 8)             ;; 8-bit reg
(sig :reg 8 :init 0)     ;; 8-bit reg with initial value
```

### Continuous assignment

```lisp
:assigns ((led clk)              ;; assign LED = CLK;
          (out (logand a b)))    ;; assign OUT = A & B;
```

### Always blocks

```lisp
;; Combinational
(always-comb sensitivity-list (statement ...))

;; Sequential
((always (posedge clk) (statement ...)))       ;; with reset
((always (posedge clk (negedge rstn)) ...))   ;; async reset
```

### Statements

```lisp
(= lhs rhs)           ;; blocking assignment
(<= lhs rhs)          ;; non-blocking assignment
(incf x)              ;; x = x + 1
(decf x)              ;; x = x - 1
(if condition (then ...) (else ...))
(case expr (val1 ...) (val2 ...) (otherwise ...))
(for ((i 0) (< i 8) (incf i)) (body ...))
(begin (stmt1) (stmt2) ...)    ;; block
```

### Expressions

```lisp
(logand a b c)         ;; a & b & c
(logor a b)            ;; a | b
(logxor a b)           ;; a ^ b
(lognot a)             ;; ~a
(slice expr hi lo)     ;; expr[hi:lo]
(concat a b c)         ;; {a, b, c}
(zero-extend expr width)   ;; {W'h0, expr}
(sign-extend expr width)   ;; {{W{expr[W-1]}}, expr}
```

### Module instances

```lisp
(instance module-name (inst-name)
         ((param val) ...)         ;; parameters (or nil)
         ((port expr) ...))        ;; port connections
```

String module names preserve case (for Gowin primitives like `"rPLL"`).

### Tasks and functions

```lisp
:tasks ((name ((param kind width) ...) (body ...)))
:functions ((name ((param kind width) ...) :returns (:reg width) :body (...)))

;; Call by name:
(task-name arg1 arg2)
(func-name arg1)
```

### Character literals

```lisp
#\U          ;; → 85
#\Return     ;; → 13
#\Newline    ;; → 10
```

## Board Support

Boards live at `boards/<name>/<name>.lisp`:

```lisp
(in-package :fab)

(fab
 (board tangnano9k
   :device "GW1NR-LV9QN88PC6/I5"
   :family "GW1N-9C"
   :clock 52
   :pins ((led 10)
          (btn 3)
          (uart-tx 17)
          (uart-rx 18))))
```

Search order:
1. `--board-dir` paths (in order)
2. Project `boards/` directory (development mode)

## Examples

| Example | Description | Files |
|---------|-------------|-------|
| `01-uart-sender` | UART character sender | 1 module + 1 testbench |
| `02-z80` | Z80 CPU core | 5 modules (ALU, regfile, uart, top) |
| `03-usb-keyboard` | USB HID keyboard (soft USB) | 11 modules |

### Running an example

```bash
# Generate only
fab examples/03-usb-keyboard/usb-keyboard.lisp

# Generate + compile for Tang Nano 9K
fab --board tangnano9k examples/03-usb-keyboard/usb-keyboard.lisp

# Flash to board
openFPGALoader -b tangnano9k build/usb-keyboard.fs -f
```

## Project Layout

```
fab/
  src/
    packages.lisp       Package definition
    ir.lisp             IR struct definitions
    emit-verilog.lisp   Verilog emitter
    fab-macro.lisp      DSL parser + fab macro
    main.lisp           CLI entry point
  boards/
    tangnano9k/
      tangnano9k.lisp   Board definition
  examples/
    01-uart-sender/     Simple UART
    02-z80/             Z80 CPU
    03-usb-keyboard/    USB HID keyboard
  build/                Generated output (gitignored)
  fab.asd               ASDF system definition
  Makefile              Top-level build
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
