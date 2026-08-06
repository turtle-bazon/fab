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
            (setf state 0)
            (setf bit-index 0)
            (setf shift-reg 0)
            (setf baud-timer 0)
            (setf tx-reg 1)
            (setf busy-reg 0)
          )
          (begin
            (case state
              (0
               (begin
                 (setf tx-reg 1)
                 (setf busy-reg 0)
                 (if write-enable
                   (begin
                     (setf shift-reg (concat 1 (slice data-in 7 0) 0))
                     (setf bit-index 0)
                     (setf baud-timer 0)
                     (setf state 1)
                     (setf busy-reg 1)
                   )
                 )
               )
              )
              (1
               (begin
                 (setf tx-reg (bit shift-reg 0))
                 (if (= baud-timer baud-timer-max)
                   (begin
                     (setf baud-timer 0)
                     (if (= bit-index 10)
                       (begin
                         (setf state 0)
                         (setf busy-reg 0)
                       )
                       (begin
                         (setf shift-reg (concat 0 (slice shift-reg 10 1)))
                         (setf bit-index (+ bit-index 1))
                       )
                     )
                   )
                   (setf baud-timer (+ baud-timer 1))
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
