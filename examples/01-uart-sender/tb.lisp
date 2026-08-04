(in-package :fab)

;;; Example 01: UART Sender — Testbench
;;; Generates tb_tb_UART_SENDER.v for iverilog simulation.

(fab
 (testbench tb-UART-SENDER
   :signals ((clk :reg) (uart-tx :wire))
   :body
   ((instance uart-sender (uut)
      ((baud-rate 115200) (clk-freq 27000000))
      ((clk clk) (uart-tx uart-tx)))
    (initial
      (= clk 0)
      (forever (begin (delay 18.5) (= clk (not clk)))))
    (initial
      ($dumpfile "build/sim.vcd")
      ($dumpvars 0 tb-UART-SENDER)
      (delay 10000000)
      ($finish))
    (initial
      ($monitor "Time=%0t uart_tx=%b" $time uart-tx)))))
