# Example 01: UART Sender

Sends `"U\r\n"` once per second at 115200 baud on the Tang Nano 9K.
The FPGA runs at 27 MHz using the onboard oscillator (no PLL).

## Files

- `uart-sender.lisp` — `(fab)` DSL source for the design module + board target
- `tb.lisp` — `(fab)` DSL source for the testbench
- `README.md` — this file

## Usage

Build bitstream (generates both `.v` and `.cst`):

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

### Design modules (board-agnostic)
```lisp
(fab
 (module name
   :depends (dep1 dep2)
   :ports ((name :input) (name :output))
   :params ((name value))
   :signals ((name :reg width) (name :reg 2 :attrs ((fsm_encoding "binary"))))
   :assigns ((lhs rhs))
   :body ((always (posedge clk) ...))))

;; Board-specific: map design ports to FPGA pins
(fab (board-target name :board :board-name))
```

### Board definitions
```lisp
(fab
 (board name
   :device "GW1NR-LV9QN88PC6/I5"
   :family "GW1N-9C"
   :clock 52
   :pins ((uart-tx 17) (uart-rx 18) (led 10))))
```

### Testbenches
```lisp
(fab
 (testbench name
   :depends (module-name)
   :signals ((name :reg) (name :wire))
   :body
   ((instance module-name (inst-name) ((param val) ...) ((port signal) ...))
    (initial (= clk 0) (delay 100) ($finish))
    (always (posedge clk) (= clk (not clk))))))
```
