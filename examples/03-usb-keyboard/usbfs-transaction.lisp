;;; USB Transaction Level Controller
;;; Translated from WangXuan95/FPGA-USB-Device reference

(in-package :fab)

(fab
 (module usbfs-transaction
   :params ((descriptor-device 0 :width 144)
            (descriptor-str1 0 :width 512)
            (descriptor-str2 0 :width 512)
            (descriptor-str3 0 :width 512)
            (descriptor-str4 0 :width 512)
            (descriptor-str5 0 :width 512)
            (descriptor-str6 0 :width 512)
            (descriptor-config 0 :width 4096)
            (ep00-maxpktsize #x20 :width 8)
            (ep81-maxpktsize #x20 :width 10)
            (ep82-maxpktsize #x20 :width 10)
            (ep83-maxpktsize #x20 :width 10)
            (ep84-maxpktsize #x20 :width 10)
            (ep81-isochronous 0)
            (ep82-isochronous 0)
            (ep83-isochronous 0)
            (ep84-isochronous 0)
            (ep01-isochronous 0)
            (ep02-isochronous 0)
            (ep03-isochronous 0)
            (ep04-isochronous 0))

   :ports ((rstn :input)
           (clk :input)
           (rp-pid :input 4)
           (rp-endp :input 4)
           (rp-byte-en :input)
           (rp-byte :input 8)
           (rp-fin :input)
           (rp-okay :input)
           (tp-sta :output :reg)
           (tp-pid :output :reg 4)
           (tp-byte-req :input)
           (tp-byte :output :reg 8)
           (tp-fin-n :output :reg)
           (sot :output :reg)
           (sof :output :reg)
           (ep00-setup-cmd :output :reg 64)
           (ep00-resp-idx :output :reg 9)
           (ep00-resp :input 8)
           (ep81-data :input 8) (ep81-valid :input) (ep81-ready :output)
           (ep82-data :input 8) (ep82-valid :input) (ep82-ready :output)
           (ep83-data :input 8) (ep83-valid :input) (ep83-ready :output)
           (ep84-data :input 8) (ep84-valid :input) (ep84-ready :output)
          (ep01-data :output :reg 8) (ep01-valid :output :reg)
          (ep02-data :output :reg 8) (ep02-valid :output :reg)
          (ep03-data :output :reg 8) (ep03-valid :output :reg)
          (ep04-data :output :reg 8) (ep04-valid :output :reg))

   :localparams ((pid-out 1 :width 4)
                 (pid-in 9 :width 4)
                 (pid-setup #xD :width 4)
                 (pid-sof 5 :width 4)
                 (pid-data0 3 :width 4)
                 (pid-data1 #xB :width 4)
                 (pid-ack 2 :width 4)
                 (pid-nak #xA :width 4)
                 (descriptor-str0 #x04030904 :width 32))

   :signals ((tp-cnt :reg 10 :init 0)
             (endp :reg 4 :init 0)
             (ep00-setup :reg :init 0)
             (ep00-total :reg 16 :init 0)
             (ep00-data :reg 8 :init 0)
             (ep00-data1 :reg :init 0)
             (ep81-data1 :reg :init 0)
             (ep82-data1 :reg :init 0)
             (ep83-data1 :reg :init 0)
             (ep84-data1 :reg :init 0)
             (ep8x-valid :wire 5))

   :assigns ((ep8x-valid (concat ep84-valid ep83-valid ep82-valid ep81-valid 1))
             (ep81-ready (and tp-byte-req (/= tp-cnt 0) (= endp 1)))
             (ep82-ready (and tp-byte-req (/= tp-cnt 0) (= endp 2)))
             (ep83-ready (and tp-byte-req (/= tp-cnt 0) (= endp 3)))
             (ep84-ready (and tp-byte-req (/= tp-cnt 0) (= endp 4))))

   :body
   (;; Main always block - handle tokens and data
    (always (posedge clk (negedge rstn))
      (if (not rstn)
        (begin
          (setf-nb tp-sta 0)
          (setf-nb tp-pid 0)
          (setf-nb tp-byte 0)
          (setf-nb tp-fin-n 0)
          (setf-nb tp-cnt 0)
          (setf-nb endp 0)
          (setf-nb ep00-setup 0)
          (setf-nb ep00-total 0)
          (setf-nb ep00-data1 0)
          (setf-nb ep81-data1 0)
          (setf-nb ep82-data1 0)
          (setf-nb ep83-data1 0)
          (setf-nb ep84-data1 0)
          (setf-nb ep00-resp-idx 0))
        (begin
          (setf-nb tp-sta 0)
          (if (and rp-fin rp-okay)
            (begin
              (if (= rp-pid pid-setup)
                (begin
                  (setf-nb endp rp-endp)
                  (if (= rp-endp 0)
                    (begin
                      (setf-nb ep00-setup 1)
                      (setf-nb ep00-data1 1))))
                (if (= rp-pid pid-out)
                  (begin
                    (setf-nb endp rp-endp)
                    (if (= rp-endp 0)
                      (setf-nb ep00-setup 0)))
                  (if (= rp-pid pid-in)
                    (begin
                      (setf-nb endp rp-endp)
                      (setf-nb tp-sta 1)
                      (setf-nb tp-pid pid-nak)
                      (setf-nb tp-cnt 0)
                      (if (= rp-endp 0)
                        (begin
                          (setf-nb ep00-setup 0)
                          (setf-nb tp-pid (if ep00-data1 pid-data1 pid-data0))
                          (if (>= ep00-total (zero-extend ep00-maxpktsize 16))
                            (begin
                              (setf-nb tp-cnt (zero-extend ep00-maxpktsize 10))
                              (setf-nb ep00-total (- ep00-total (zero-extend ep00-maxpktsize 16))))
                            (begin
                              (setf-nb tp-cnt (zero-extend (slice ep00-total 7 0) 10))
                              (setf-nb ep00-total 0))))
                          (if (= rp-endp 1)
                            (if ep81-valid
                              (begin
                                (setf-nb tp-pid (if (and ep81-data1 (not ep81-isochronous)) pid-data1 pid-data0))
                                (setf-nb tp-cnt ep81-maxpktsize)))
                            (if (= rp-endp 2)
                              (if ep82-valid
                                (begin
                                  (setf-nb tp-pid (if (and ep82-data1 (not ep82-isochronous)) pid-data1 pid-data0))
                                  (setf-nb tp-cnt ep82-maxpktsize)))
                              (if (= rp-endp 3)
                                (if ep83-valid
                                  (begin
                                    (setf-nb tp-pid (if (and ep83-data1 (not ep83-isochronous)) pid-data1 pid-data0))
                                    (setf-nb tp-cnt ep83-maxpktsize)))
                                (if (= rp-endp 4)
                                  (if ep84-valid
                                    (begin
                                      (setf-nb tp-pid (if (and ep84-data1 (not ep84-isochronous)) pid-data1 pid-data0))
                                      (setf-nb tp-cnt ep84-maxpktsize))))))))))
                    (if (= rp-pid pid-ack)
                      (begin
                        (if (= endp 0)
                          (setf-nb ep00-data1 (not ep00-data1))
                          (if (= endp 1)
                            (setf-nb ep81-data1 (and (not ep81-data1) (not ep81-isochronous)))
                            (if (= endp 2)
                              (setf-nb ep82-data1 (and (not ep82-data1) (not ep82-isochronous)))
                              (if (= endp 3)
                                (setf-nb ep83-data1 (and (not ep83-data1) (not ep83-isochronous)))
                                (if (= endp 4)
                                  (setf-nb ep84-data1 (and (not ep84-data1) (not ep84-isochronous)))))))))
                      (if (or (= rp-pid pid-data0) (= rp-pid pid-data1))
                        (begin
                          (if (= endp 0)
                            (begin
                              (setf-nb ep00-total 0)
                              (if ep00-setup
                                (begin
                                  (if (bit ep00-setup-cmd 7)
                                    (setf-nb ep00-total (slice ep00-setup-cmd 63 48)))
                                  (setf-nb ep00-resp-idx 0)))))
                          (setf-nb tp-sta 1)
                          (setf-nb tp-pid pid-ack)
                          (if (or (and (= endp 1) ep01-isochronous)
                                  (and (= endp 2) ep02-isochronous)
                                  (and (= endp 3) ep03-isochronous)
                                  (and (= endp 4) ep04-isochronous))
                            (setf-nb tp-sta 0))))))))
          (if tp-byte-req
            (begin
              (setf-nb tp-fin-n 0)
              (if (and (/= tp-cnt 0)
                       (or (= endp 0)
                           (and (= endp 1) ep81-valid)
                           (and (= endp 2) ep82-valid)
                           (and (= endp 3) ep83-valid)
                           (and (= endp 4) ep84-valid)))
                (begin
                  (setf-nb tp-cnt (- tp-cnt 1))
                  (setf-nb tp-fin-n 1)
                  (case endp
                    (0 (setf-nb tp-byte ep00-data))
                    (1 (setf-nb tp-byte ep81-data))
                    (2 (setf-nb tp-byte ep82-data))
                    (3 (setf-nb tp-byte ep83-data))
                    (4 (setf-nb tp-byte ep84-data)))
                  (if (= endp 0)
                     (setf-nb ep00-resp-idx (+ ep00-resp-idx 1)))))))))))

    ;; Response IN data on endpoint 0
    (always (posedge clk)
      (if (and (>= (slice ep00-setup-cmd 15 8) #x08)
               (= (slice ep00-setup-cmd 7 0) #x80))
        (setf ep00-data (if (>= ep00-resp-idx 1) 0 1))
        (if (and (= (slice ep00-setup-cmd 31 24) #x01)
                 (= (slice ep00-setup-cmd 15 0) #x0680))
          (setf ep00-data (if (>= ep00-resp-idx 18) 0
                             (slice descriptor-device (+ (* (- 17 ep00-resp-idx) 8) 7) (* (- 17 ep00-resp-idx) 8))))
          (if (and (= (slice ep00-setup-cmd 31 24) #x02)
                   (= (slice ep00-setup-cmd 15 0) #x0680))
            (setf ep00-data (slice descriptor-config (+ (* (- 511 ep00-resp-idx) 8) 7) (* (- 511 ep00-resp-idx) 8)))
            (if (= ep00-setup-cmd #x03000680)
              (setf ep00-data (if (>= ep00-resp-idx 4) 0
                                 (slice descriptor-str0 (+ (* (- 3 ep00-resp-idx) 8) 7) (* (- 3 ep00-resp-idx) 8))))
              (if (= ep00-setup-cmd #x03010680)
                (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                   (slice descriptor-str1 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                (if (= ep00-setup-cmd #x03020680)
                  (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                     (slice descriptor-str2 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                  (if (= ep00-setup-cmd #x03030680)
                    (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                       (slice descriptor-str3 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                    (if (= ep00-setup-cmd #x03040680)
                      (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                         (slice descriptor-str4 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                      (if (= ep00-setup-cmd #x03050680)
                        (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                           (slice descriptor-str5 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                        (if (= ep00-setup-cmd #x03060680)
                          (setf ep00-data (if (>= ep00-resp-idx 64) 0
                                             (slice descriptor-str6 (+ (* (- 63 ep00-resp-idx) 8) 7) (* (- 63 ep00-resp-idx) 8))))
                            (setf ep00-data ep00-resp))))))))))))

    ;; Process OUT data
    (always (posedge clk (negedge rstn))
      (if (not rstn)
        (begin
          (setf-nb ep00-setup-cmd 0)
          (setf-nb ep01-data 0) (setf-nb ep01-valid 0)
          (setf-nb ep02-data 0) (setf-nb ep02-valid 0)
          (setf-nb ep03-data 0) (setf-nb ep03-valid 0)
          (setf-nb ep04-data 0) (setf-nb ep04-valid 0))
        (begin
          (setf-nb ep01-data 0) (setf-nb ep01-valid 0)
          (setf-nb ep02-data 0) (setf-nb ep02-valid 0)
          (setf-nb ep03-data 0) (setf-nb ep03-valid 0)
          (setf-nb ep04-data 0) (setf-nb ep04-valid 0)
          (if rp-byte-en
            (if (= endp 0)
              (if ep00-setup
                (setf-nb ep00-setup-cmd (concat rp-byte (slice ep00-setup-cmd 63 8))))
              (if (= endp 1)
                (begin (setf-nb ep01-data rp-byte) (setf-nb ep01-valid 1))
                (if (= endp 2)
                  (begin (setf-nb ep02-data rp-byte) (setf-nb ep02-valid 1))
                  (if (= endp 3)
                    (begin (setf-nb ep03-data rp-byte) (setf-nb ep03-valid 1))
                    (if (= endp 4)
                      (begin (setf-nb ep04-data rp-byte) (setf-nb ep04-valid 1)))))))))))

    ;; Detect IN/OUT packet border and SOF
    (always (posedge clk (negedge rstn))
      (if (not rstn)
        (begin
          (setf-nb sot 0)
          (setf-nb sof 0))
        (begin
          (setf-nb sot 0)
          (setf-nb sof 0)
          (if (and rp-fin rp-okay)
            (begin
              (if (= rp-endp 0)
                (setf-nb sot (= rp-pid pid-setup))
                (setf-nb sot (or (= rp-pid pid-in) (= rp-pid pid-out))))
              (setf-nb sof (= rp-pid pid-sof))))))))))