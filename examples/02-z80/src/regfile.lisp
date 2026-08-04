(in-package :fab)

(fab
 (module z80-regfile
   :ports ((clk :input) (we :input)
           (a1-select :input 3) (a1-data :output 8)
           (a2-select :input 3) (a2-data :output 8)
           (a3-select :input 3) (a3-data :input 8)
           (pc-in :input 16) (pc-out :output 16)
           (sp-in :input 16) (sp-out :output 16))
   :signals ((b :reg 8) (c :reg 8)
             (d :reg 8) (e :reg 8)
             (h :reg 8) (l :reg 8)
             (a :reg 8) (f :reg 8)
             (pc :reg 16) (sp :reg 16)
             (a1-val :reg 8) (a2-val :reg 8))
   :body
   ((always
      (posedge clk)
      (begin
        (if we
          (begin
            (case a3-select
              (0 (setf b a3-data))
              (1 (setf c a3-data))
              (2 (setf d a3-data))
              (3 (setf e a3-data))
              (4 (setf h a3-data))
              (5 (setf l a3-data))
              (6 (setf a a3-data))
              (7 (setf f a3-data))
            )
          )
        )
        (setf pc pc-in)
        (setf sp sp-in)
      )
    )
    (always-comb
      (case a1-select
        (0 (setf a1-val b))
        (1 (setf a1-val c))
        (2 (setf a1-val d))
        (3 (setf a1-val e))
        (4 (setf a1-val h))
        (5 (setf a1-val l))
        (6 (setf a1-val a))
        (7 (setf a1-val f))
      )
      (case a2-select
        (0 (setf a2-val b))
        (1 (setf a2-val c))
        (2 (setf a2-val d))
        (3 (setf a2-val e))
        (4 (setf a2-val h))
        (5 (setf a2-val l))
        (6 (setf a2-val a))
        (7 (setf a2-val f))
      )
    )
   )
   :assigns ((a1-data a1-val) (a2-data a2-val)
             (pc-out pc) (sp-out sp))))
