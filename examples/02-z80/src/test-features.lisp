(in-package :fab)

(fab
 (module test-features
   :ports ((a :input 8) (b :input 8) (sel :input 3) (y :output 8))
   :signals ((r :reg 8))
   :body
   ((always-comb
      (setf r 0)
      (case sel
        (0 (setf r (+ a b)))
        (1 (setf r (- a b)))
        (2 (setf r (logand a b)))
        (3 (setf r (logor a b)))
        (4 (setf r (logxor a b)))
        (5 (setf r (lognot a)))
        (6 (setf r (concat (bit a 6) (bit a 5) (bit a 4) (bit a 3)
                           (bit a 2) (bit a 1) (bit a 0) (bit a 7))))
        (7 (setf r (if (= a 0) #xFF 0))))))
   :assigns ((y r))))
