;;; Debug UART transmitter - 8N1, parameterized baud rate
;;; Simplified from WangXuan95/FPGA-USB-Device

(in-package :fab)

(fab
 (module usbfs-debug-uart-tx
   :ports ((rstn :input)
           (clk :input)
           (tx-data :input 8)
           (tx-en :input)
           (tx-rdy :output)
           (o-uart-tx :output :reg))
   :signals ((tx-clk-cnt :reg 16 :init 0)
             (tx-state :reg 4 :init 0)
             (tx-shift :reg 8 :init 0))
   :body
   ((always-comb
     (setf tx-rdy (if (= tx-state 0) 1 0))
     (case tx-state
       (0 (setf o-uart-tx 1))
       (1 (setf o-uart-tx 0))
       (2 (setf o-uart-tx (bit tx-shift 0)))
       (3 (setf o-uart-tx (bit tx-shift 1)))
       (4 (setf o-uart-tx (bit tx-shift 2)))
       (5 (setf o-uart-tx (bit tx-shift 3)))
       (6 (setf o-uart-tx (bit tx-shift 4)))
       (7 (setf o-uart-tx (bit tx-shift 5)))
       (8 (setf o-uart-tx (bit tx-shift 6)))
       (otherwise (setf o-uart-tx 1))))
    (always
      (posedge clk)
      (if (= tx-state 0)
        (begin
          (if tx-en
            (begin
              (setf tx-shift tx-data)
              (setf tx-state 1)
              (setf tx-clk-cnt 0))))
        (begin
          (if (= tx-clk-cnt 520)
            (begin
              (setf tx-clk-cnt 0)
              (incf tx-state))
            (begin
              (incf tx-clk-cnt)))))))))
