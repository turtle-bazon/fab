(in-package :fab)

(fab
 (module z80-uart
   :ports ((clk :input) (rst :input)
           (tx :output) (busy :output)
           (data-in :input 8) (write-enable :input))
   :localparams ((baud-timer-max 234))
   :signals ((state :reg 2) (bit-index :reg 4)
             (shift-reg :reg 11) (baud-timer :reg 9)
             (tx-reg :reg) (busy-reg :reg))
   :body
   ((always
      (posedge clk)
      (begin
        (if rst
          (begin
            (= state 0)
            (= bit-index 0)
            (= shift-reg 0)
            (= baud-timer 0)
            (= tx-reg 1)
            (= busy-reg 0)
          )
          (begin
            (case state
              (0
               (begin
                 (= tx-reg 1)
                 (= busy-reg 0)
                 (if write-enable
                   (begin
                     (= shift-reg (concat 1 (slice data-in 7 0) 0))
                     (= bit-index 0)
                     (= baud-timer 0)
                     (= state 1)
                     (= busy-reg 1)
                   )
                 )
               )
              )
              (1
               (begin
                 (= tx-reg (bit shift-reg 0))
                 (if (= baud-timer baud-timer-max)
                   (begin
                     (= baud-timer 0)
                     (if (= bit-index 10)
                       (begin
                         (= state 0)
                         (= busy-reg 0)
                       )
                       (begin
                         (= shift-reg (concat 0 (slice shift-reg 10 1)))
                         (= bit-index (+ bit-index 1))
                       )
                     )
                   )
                   (= baud-timer (+ baud-timer 1))
                 )
               )
              )
            )
          )
        )
      )
    )
   )
   :assigns ((tx tx-reg) (busy busy-reg))))
