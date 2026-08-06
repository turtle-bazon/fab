(in-package :fab)

(fab
 (module usbfs-packet-tx
  :ports ((rstn :input)
          (clk :input)
          (tp-sta :input)
          (tp-pid :input 4)
          (tp-byte-req :output 1 :reg)
          (tp-byte :input 8)
          (tp-fin-n :input)
          (tx-sta :output)
          (tx-req :input)
          (tx-bit :output 1 :reg)
          (tx-fin :output 1 :reg))

  :signals ((pid :reg 8)
            (cnt :reg 4)
            (crc16 :reg 16)
            (crc16-xor :wire 1)
            (crc16-next :wire 16)
            (state :reg 3))

  :localparams ((s-idle 0)
                (s-txpid 1)
                (s-txdata 2)
                (s-txcrc 3)
                (s-txfin 4))

  :assigns ((tx-sta tp-sta)
            (crc16-xor (logxor (bit crc16 15) (bit tp-byte cnt))))

  :body
  ((always-comb
    (begin
      (setf crc16-next (logxor (logior (lsh crc16 1) 0)
                               (logior (lsh crc16-xor 15)
                                       (lsh crc16-xor 2)
                                       crc16-xor)))))

   (always
      (posedge clk)
    (if (not rstn)
      (begin
        (setf-nb tp-byte-req 0)
        (setf-nb tx-bit 0)
        (setf-nb tx-fin 0)
        (setf-nb pid 0)
        (setf-nb cnt 0)
        (setf-nb crc16 #xFFFF)
        (setf-nb state s-idle))
      (begin
        (setf-nb tp-byte-req 0)
        (setf-nb tx-bit 0)
        (setf-nb tx-fin 0)
        (case state
          (s-idle
           (setf-nb pid (concat (lognot tp-pid) tp-pid))
           (setf-nb cnt 0)
           (setf-nb crc16 #xFFFF)
           (if tp-sta
             (setf-nb state s-txpid)))
          (s-txpid
           (if tx-req
             (begin
               (setf-nb tx-bit (bit pid cnt))
               (if (/= cnt 7)
                 (setf-nb cnt (+ cnt 1))
                 (begin
                   (setf-nb cnt 0)
                   (if (= (slice pid 1 0) 3)
                     (begin
                       (setf-nb tp-byte-req 1)
                       (setf-nb state s-txdata))
                     (setf-nb state s-txfin)))))))
          (s-txdata
           (if (and (not tp-byte-req) (not tp-fin-n))
             (begin
               (setf-nb crc16 (lognot crc16))
               (setf-nb state s-txcrc))
             (if (and (not tp-byte-req) tx-req)
               (begin
                 (setf-nb crc16 crc16-next)
                 (setf-nb tx-bit (bit tp-byte cnt))
                 (if (/= cnt 7)
                   (setf-nb cnt (+ cnt 1))
                   (begin
                     (setf-nb cnt 0)
                     (setf-nb tp-byte-req 1)))))))
          (s-txcrc
           (if tx-req
             (begin
               (setf-nb tx-bit (bit crc16 0))
               (setf-nb crc16 (logior (lsh crc16 1) 0))
               (if (/= cnt 15)
                 (setf-nb cnt (+ cnt 1))
                 (setf-nb state s-txfin)))))
          (otherwise
           (if tx-req
             (begin
               (setf-nb tx-fin 1)
                (setf-nb state s-idle)))))))))))
