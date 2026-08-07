(in-package :fab)

(fab
 (module z80
   :board tangnano9k
   :ports ((clk :input) (rst :input) (led :output)
           (uart-tx :output))
   :signals ((led-state :reg)
             (led-timer :reg 25)
             (uart-busy-alu :wire)
             (uart-tx-pin :wire)
             (alu-a :wire 8)
             (alu-b :wire 8)
             (alu-op-wire :wire 4)
             (alu-flags-in-wire :wire 8)
             (alu-carry-in-wire :wire)
             (alu-result-wire :wire 8)
             (alu-flags-out-wire :wire 8)
             (uart-data-wire :wire 8)
             (uart-write-wire :wire)
             (ctrl-state :reg 3)
             (test-char :reg 8))
   :assigns ((led led-state) (uart-tx uart-tx-pin))
   :body
   ((always
      (posedge clk)
      (begin
        (if rst
           (begin
             (setf led-state 0)
             (setf led-timer 0)
             (setf alu-a 0)
             (setf alu-b 0)
             (setf alu-op-wire 0)
             (setf alu-flags-in-wire 0)
             (setf alu-carry-in-wire 0)
             (setf uart-data-wire 0)
             (setf uart-write-wire 0)
             (setf ctrl-state 0)
             (setf test-char #x41)
           )
           (begin
             (setf uart-write-wire 0)
             (incf led-timer)
             (if (= led-timer 13500000)
               (begin
                 (setf led-timer 0)
                 (setf led-state (lognot led-state))
               )
             )
             (case ctrl-state
               (0
                (begin
                  (setf alu-a test-char)
                  (setf alu-b 0)
                  (setf alu-op-wire 6)
                  (setf ctrl-state 1)
                )
               )
               (1
                (begin
                  (if (= uart-busy-alu 0)
                    (begin
                      (setf uart-data-wire alu-result-wire)
                      (setf uart-write-wire 1)
                      (incf test-char)
                      (if (= test-char #x5A)
                        (setf ctrl-state 2)
                        (setf ctrl-state 0)
                      )
                    )
                  )
                )
               )
               (2
                (begin
                  (setf test-char #x41)
                  (setf ctrl-state 0)
                )
               )
             )
           )
        )
      )
    )
    (instance z80-alu (alu0)
     ()
     ((a-in alu-a) (b-in alu-b) (alu-op alu-op-wire)
      (flags-in alu-flags-in-wire) (carry-in alu-carry-in-wire)
      (result alu-result-wire) (flags-out alu-flags-out-wire)))
    (instance z80-uart (uart0)
     ()
     ((clk clk) (rst rst) (tx uart-tx-pin)
      (busy uart-busy-alu) (data-in uart-data-wire)
      (write-enable uart-write-wire)))
   )))
