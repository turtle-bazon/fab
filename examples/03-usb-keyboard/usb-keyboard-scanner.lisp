;;; USB Keyboard scanner - cycles through keys a-z, 0-9
;;; Outputs: key_value (16-bit HID usage code), key_request (1-cycle pulse)

(in-package :fab)

(fab
 (module usb-keyboard-scanner
   :ports ((clk :input) (rst :input)
           (key-value :output 16) (key-request :output))
   :signals ((count :reg 32)
             (key-val :reg 16))
   :assigns ((key-value key-val))
   :body
   ((always
     (posedge clk)
     (begin
       (if rst
         (begin
           (setf count 0)
           (setf key-val #x0004)
           (setf key-request 0))
         (begin
           (setf key-request 0)
           (if (< count 54000000)
             (begin
               (setf count (+ count 1)))
             (begin
               (setf count 0)
               (setf key-request 1)
               (if (< key-val #x0027)
                 (setf key-val (+ key-val 1))
                 (setf key-val #x0004)))))))))))
