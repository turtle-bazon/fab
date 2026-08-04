(in-package :fab)

(fab
 (module z80-alu
   :ports ((a-in :input 8) (b-in :input 8) (alu-op :input 4)
           (flags-in :input 8) (carry-in :input)
           (result :output 8) (flags-out :output 8))
   :signals ((res :reg 8) (flags :reg 8))
   :body
   ((always-comb
      (= res 0)
      (= flags flags-in)
      (case alu-op
        (0 (setf res (+ a-in b-in))
           (setf flags (logor (logand flags-in #xEC) (logor (logand (if (> (+ a-in b-in) #xFF) 1 0) #x01) (logor (logand (if (> (+ (logand a-in #x0F) (logand b-in #x0F)) #x0F) 1 0) #x10) (logor (logand (if (and (= (bit a-in 7) (bit b-in 7)) (/= (bit a-in 7) (bit res 7))) 1 0) #x04) (logor (logand (if (= res 0) 1 0) #x40) (logand (bit res 7) #x80))))))))
        (2 (setf res (- a-in b-in))
           (setf flags (logor (logand flags-in #xEC) (logor (logand (if (< a-in b-in) 1 0) #x01) (logor (logand (if (< (logand a-in #x0F) (logand b-in #x0F)) 1 0) #x10) (logor (logand (if (and (/= (bit a-in 7) (bit b-in 7)) (= (bit a-in 7) (bit res 7))) 1 0) #x04) (logor (logand (if (= res 0) 1 0) #x40) (logand (bit res 7) #x80))))))))
        (4 (setf res (logand a-in b-in))
           (setf flags (logor (logand flags-in #xAC) (logor (logand (bit res 7) #x80) (logand (if (= res 0) #x40 0) #x40)))))
        (5 (setf res (logor a-in b-in))
           (setf flags (logor (logand flags-in #xAC) (logor (logand (bit res 7) #x80) (logand (if (= res 0) #x40 0) #x40)))))
        (6 (setf res (logxor a-in b-in))
           (setf flags (logor (logand flags-in #xAC) (logor (logand (bit res 7) #x80) (logand (if (= res 0) #x40 0) #x40)))))
        (8 (setf res (+ a-in 1))
           (setf flags (logor (logand flags-in #xED) (logor (logand (if (> (logand a-in #x0F) #x0E) 1 0) #x10) (logor (logand (if (= a-in #x7F) 1 0) #x04) (logor (logand (if (= res 0) 1 0) #x40) (logand (bit res 7) #x80)))))))
        (9 (setf res (- a-in 1))
           (setf flags (logor (logand flags-in #xED) (logor (logand (if (< (logand a-in #x0F) 1) 1 0) #x10) (logor (logand (if (= a-in #x80) 1 0) #x04) (logor (logand (if (= res 0) 1 0) #x40) (logand (bit res 7) #x80)))))))
        (14 (setf res (lognot a-in))
            (setf flags (logor (logand flags-in #xED) #x10)))))
   )
   :assigns ((result res) (flags-out flags))))
