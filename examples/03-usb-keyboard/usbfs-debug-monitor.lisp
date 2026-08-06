;;; USB debug monitor - outputs packet info as bytes
;;; From WangXuan95/FPGA-USB-Device

(in-package :fab)

(fab
 (module usbfs-debug-monitor
   :ports ((rstn :input)
           (clk :input)
           (rp-pid :input 4)
           (rp-endp :input 4)
           (rp-byte-en :input)
           (rp-byte :input 8)
           (rp-fin :input)
           (rp-okay :input)
           (tp-pid :input 4)
           (tp-byte-req :input)
           (tp-byte :input 8)
           (tp-fin-n :input)
           (debug-en :output)
           (debug-data :output 8))
   :signals ((state :reg 8 :init 0))
   :localparams ((rx-marker 10)    ; 0xA = "Rx" marker
                 (tx-marker 11))   ; 0xB = "Tx" marker
    :assigns ((debug-en (if (logor (= state 0) (= state 2) (= state 4))
                           (if (= state 0) 1
                             (if (= state 2) (if rp-byte-en 1 0)
                               (if (= state 4) (if tp-byte-req 1 0) 0)))
                           (if (= state 1) 1
                             (if (= state 3) 1 0))))
              (debug-data (if (= state 0) (concat rx-marker rp-pid)
                            (if (= state 2) rp-byte
                              (if (= state 3) (concat tx-marker tp-pid)
                                (if (= state 4) tp-byte 0))))))
    :body
    ((always
      (posedge clk)
      (if (not rstn)
        (begin
          (setf state 0))
        (begin
          (case state
            (0 (if (logand rp-fin rp-okay)
                 (setf state 1)))
            (1 (setf state 2))
            (2 (if (not rp-byte-en)
                 (if rp-fin
                   (setf state 3))))
            (3 (if tp-fin-n
                 (setf state 4)
               (if (logand (not tp-fin-n) (not tp-byte-req))
                 (setf state 0))))
            (4 (if (not tp-byte-req)
                 (if tp-fin-n
                   (setf state 3)
                   (setf state 0)))))))))))
