(in-package :fab)

(fab
 (module usbfs-packet-rx
  :ports ((rstn :input)
          (clk :input)
          (rx-sta :input)
          (rx-ena :input)
          (rx-bit :input)
          (rx-fin :input)
          (rp-pid :output 4 :reg)
          (rp-addr :output 11 :reg)
          (rp-byte-en :output 1 :reg)
          (rp-byte :output 8 :reg)
          (rp-fin :output 1 :reg)
          (rp-okay :output 1 :reg))

  :signals ((rx-valid :reg 1)
            (rx-bytecnt :reg 2)
            (rx-bcnt :reg 5)
            (rx-cnt :reg 3)
            (rx-shift :reg 24)
            (rx-crc5 :reg 5)
            (rx-crc16 :reg 16)
            (rx-shift-next :wire 24)
            (crc5-xor :wire 1)
            (crc5-next :wire 5)
            (crc16-xor :wire 1)
            (crc16-next :wire 16))

  :assigns ((rx-shift-next (concat rx-bit (slice rx-shift 23 1)))
            (crc5-xor (logxor (bit rx-crc5 4) (bit rx-shift-next 18)))
            (crc5-next (logxor (logior (lsh rx-crc5 1) 0)
                               (logior (lsh crc5-xor 4)
                                       (lsh crc5-xor 1)
                                       crc5-xor)))
            (crc16-xor (logxor (bit rx-crc16 15) (bit rx-shift-next 7)))
            (crc16-next (logxor (logior (lsh rx-crc16 1) 0)
                                (logior (lsh crc16-xor 15)
                                        (lsh crc16-xor 2)
                                        crc16-xor))))

  :body
  ((always
      (posedge clk)
    (if (not rstn)
      (begin
        (setf-nb rp-pid 0)
        (setf-nb rp-addr 0)
        (setf-nb rp-byte-en 0)
        (setf-nb rp-byte 0)
        (setf-nb rx-valid 0)
        (setf-nb rx-bytecnt 0)
        (setf-nb rx-bcnt 0)
        (setf-nb rx-cnt 0)
        (setf-nb rx-shift 0)
        (setf-nb rx-crc5 #x1F)
        (setf-nb rx-crc16 #xFFFF))
      (begin
        (setf-nb rp-byte-en 0)
        (if rx-sta
          (begin
            (setf-nb rp-pid 0)
            (setf-nb rx-valid 0)
            (setf-nb rx-bytecnt 0)
            (setf-nb rx-bcnt 0)
            (setf-nb rx-cnt 0)
            (setf-nb rx-shift 0)
            (setf-nb rx-crc5 #x1F)
            (setf-nb rx-crc16 #xFFFF))
          (if rx-ena
            (begin
              (setf-nb rx-cnt (+ rx-cnt 1))
              (setf-nb rx-shift rx-shift-next)
              (if (/= rx-bytecnt 0)
                (begin
                  (if (>= rx-bcnt 5)
                    (setf-nb rx-crc5 crc5-next))
                  (if (>= rx-bcnt 16)
                    (setf-nb rx-crc16 crc16-next))
                  (if (/= rx-bcnt 31)
                    (setf-nb rx-bcnt (+ rx-bcnt 1)))))
              (if (= rx-cnt 7)
                (begin
                  (if (= rx-bytecnt 0)
                    (if (= (logand (logxor (slice rx-shift-next 23 20)
                                            (slice rx-shift-next 19 16))
                                    #xF)
                           #xF)
                      (begin
                        (setf-nb rx-valid 1)
                        (setf-nb rp-pid (slice rx-shift-next 19 16)))))
                  (if (and (= rx-bytecnt 2) rx-valid (= (slice rp-pid 1 0) 1))
                    (setf-nb rp-addr (slice rx-shift-next 18 8)))
                  (if (and (= rx-bytecnt 3) rx-valid (= (slice rp-pid 1 0) 3))
                    (begin
                      (setf-nb rp-byte-en 1)
                      (setf-nb rp-byte (slice rx-shift-next 7 0))))
                  (if (/= rx-bytecnt 3)
                    (setf-nb rx-bytecnt (+ rx-bytecnt 1)))))))))))

   (always
      (posedge clk)
    (if (not rstn)
      (begin
        (setf-nb rp-fin 0)
        (setf-nb rp-okay 0))
      (begin
        (setf-nb rp-fin rx-fin)
        (case (slice rp-pid 1 0)
          (1
           (setf-nb rp-okay (and rx-valid
                                 (= (logxor (lognot (slice rx-crc5 4 0))
                                            (slice rx-shift 23 19))
                                    #x1F))))
          (2
           (setf-nb rp-okay rx-valid))
          (3
           (setf-nb rp-okay (and rx-valid
                                 (= (logxor (lognot (slice rx-crc16 15 0))
                                            (slice rx-shift 23 8))
                                    #xFFFF))))
          (otherwise
           (setf-nb rp-okay 0)))))))))
