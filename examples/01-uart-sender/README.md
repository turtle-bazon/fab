# Example 01: UART Sender

Sends `"U\r\n"` once per second at 115200 baud on the Tang Nano 9K.
The FPGA runs at 27 MHz using the onboard oscillator (no PLL).

## Files

- `uart-sender.lisp` — `(fab)` DSL source for the design module
- `tb.lisp` — `(fab)` DSL source for the testbench
- `README.md` — this file

## Usage

Generate Verilog:

```lisp
(asdf:load-system :fab)
(load "examples/01-uart-sender/uart-sender.lisp")
;; => writes build/UART_SENDER.v

(load "examples/01-uart-sender/tb.lisp")
;; => writes build/TB_UART_SENDER.v
```

To redirect output to a different directory:

```lisp
(let ((*output-dir* "rtl"))
  (load "examples/01-uart-sender/uart-sender.lisp"))
;; => writes rtl/UART_SENDER.v
```

Simulate (requires iverilog):

```sh
iverilog -o build/sim_tb.vvp build/UART_SENDER.v build/TB_UART_SENDER.v
vvp build/sim_tb.vvp
```

Build bitstream:

```sh
make DESIGN=examples/01-uart-sender/uart-sender.lisp
```

Flash to Tang Nano 9K:

```sh
openFPGALoader -b tangnano9k build/uart-sender.fs -f
```

Check output:

```sh
stty -F /dev/ttyUSB1 115200 raw -echo
cat /dev/ttyUSB1
```

## DSL Syntax Reference

### Design modules
```lisp
(fab
 (module name
   :ports ((name :input) (name :output))
   :params ((name value))
   :signals ((name :reg width))
   :assigns ((lhs rhs))
   :body ((always (posedge clk) ...))))
```

### Testbenches
```lisp
(fab
 (testbench name
   :signals ((name :reg) (name :wire))
   :body
   ((instance module-name (inst-name) ((param val) ...) ((port signal) ...))
    (initial (= clk 0) (delay 100) ($finish))
    (always (posedge clk) (= clk (not clk))))))
```
