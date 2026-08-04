(in-package :fab)

;;; Example 01: UART Sender
;;; Sends "U\r\n" once per second at 115200 baud on Tang Nano 9K.
;;; Run: (asdf:load-system :fab) then (load "examples/01-uart-sender/uart-sender.lisp")

(fab
 (module uart-sender
   :board :tangnano9k
   :ports ((clk :input) (uart-tx :output) (led :output))
   :params ((baud-rate 115200) (clk-freq 27000000))
   :localparams ((baud-count (/ clk-freq baud-rate))
                 (state-idle 0)
                 (state-start 1)
                 (state-data 2)
                 (state-stop 3))
   :signals ((tx-counter :reg 16 :init 0) (state :reg 2 :init 0 :attrs ((fsm_encoding "binary")))
              (shift-reg :reg 8) (bit-index :reg 4 :init 0) (tx-bit :reg :init 1)
              (blink-counter :reg 25 :init 0) (wait-counter :reg 25 :init 0) (msg-index :reg 2 :init 0))
   :functions ((get-char ((idx :reg 2)) :returns (:reg 8)
                  :body ((case idx
                           (0 (setf get-char #\U))
                           (1 (setf get-char #\Return))
                           (2 (setf get-char #\Newline))))))
   :tasks ((load-char ((c :reg 8))
              (setf-nb shift-reg c)
              (setf-nb bit-index 0)
              (setf-nb state state-start))

           (wait-1-second-and-begin-transmit ()
              (if (= wait-counter (- clk-freq 1))
                  (begin
                    (setf-nb wait-counter 0)
                    (load-first-char))
                  (incf-nb wait-counter)))

           (load-first-char ()
              (load-char (get-char 0)))

           (wait-start-period ()
              (if (= tx-counter (- baud-count 1))
                  (begin
                    (setf-nb tx-counter 0)
                    (setf-nb state state-data))
                  (incf-nb tx-counter)))

           (wait-data-period ()
              (if (= tx-counter (- baud-count 1))
                  (begin
                    (setf-nb tx-counter 0)
                    (if (= bit-index 7)
                        (setf-nb state state-stop)
                        (incf-nb bit-index)))
                  (incf-nb tx-counter)))

           (wait-stop-period ()
              (if (= tx-counter (- baud-count 1))
                  (begin
                    (setf-nb tx-counter 0)
                    (if (< msg-index 2)
                        (begin
                          (incf-nb msg-index)
                          (load-char (get-char (+ msg-index 1))))
                        (setf-nb state state-idle)))
                  (incf-nb tx-counter))))
   :assigns ((uart-tx tx-bit) (led (bit blink-counter 24)))
   :body
   (;; Timing: count delays, transition states, shift data
    (always (posedge clk)
       (incf-nb blink-counter)
      (case state
        (state-idle (wait-1-second-and-begin-transmit))
        (state-start (wait-start-period))
        (state-data (wait-data-period))
        (state-stop (wait-stop-period))))
    ;; Output: drive TX pin based on current state
    (always (posedge clk)
      (case state
        (state-idle (setf-nb tx-bit 1))
        (state-start (setf-nb tx-bit 0))
        (state-data (setf-nb tx-bit (bit shift-reg bit-index)))
        (state-stop (setf-nb tx-bit 1)))))))
