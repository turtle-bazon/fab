(in-package :fab)

;;; Example 01: UART Sender
;;; Sends "U\r\n" once per second at 115200 baud on Tang Nano 9K.
;;; Run: (asdf:load-system :fab) then (load "examples/01-uart-sender/uart-sender.lisp")

(fab
 (module uart-sender
   :ports ((clk :input) (uart-tx :output) (led :output))
   :params ((baud-rate 115200) (clk-freq 27000000))
   :localparams ((baud-count (/ clk-freq baud-rate)))
   :signals ((tx-counter :reg 16) (state :reg 2 :attrs ((fsm_encoding "binary")))
             (shift-reg :reg 8) (bit-index :reg 4) (tx-bit :reg)
             (blink-counter :reg 25) (wait-counter :reg 25) (msg-index :reg 2))
   :assigns ((uart-tx tx-bit) (led (bit blink-counter 24)))
   :body
   ((always (posedge clk)
      (<= blink-counter (+ blink-counter 1))
      (case state
        (0
         (if (= wait-counter (- clk-freq 1))
             (begin
               (<= wait-counter 0)
               (<= shift-reg 85)
               (<= bit-index 0)
               (<= msg-index 0)
               (<= state 1))
             (<= wait-counter (+ wait-counter 1))))
        (1
         (if (= tx-counter (- baud-count 1))
             (begin
               (<= tx-counter 0)
               (<= state 2))
             (<= tx-counter (+ tx-counter 1))))
        (2
         (if (= tx-counter (- baud-count 1))
             (begin
               (<= tx-counter 0)
               (if (= bit-index 7)
                   (<= state 3)
                   (<= bit-index (+ bit-index 1))))
             (<= tx-counter (+ tx-counter 1))))
        (3
         (if (= tx-counter (- baud-count 1))
             (begin
               (<= tx-counter 0)
               (if (= msg-index 0)
                   (begin
                     (<= shift-reg 13)
                     (<= bit-index 0)
                     (<= msg-index 1)
                     (<= state 1))
                   (if (= msg-index 1)
                       (begin
                         (<= shift-reg 10)
                         (<= bit-index 0)
                         (<= msg-index 2)
                         (<= state 1))
                       (<= state 0))))
             (<= tx-counter (+ tx-counter 1))))))
     (always (posedge clk)
       (case state
         (0 (<= tx-bit 1))
         (1 (<= tx-bit 0))
         (2 (<= tx-bit (bit shift-reg bit-index)))
         (3 (<= tx-bit 1))))))))
