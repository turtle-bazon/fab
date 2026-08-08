(in-package :fab)

;;; Verilog emitter — walks IR and writes Verilog-2001 text.
;;; Keeps output boring and portable: one clock, synchronous logic, no vendor IP.

(defparameter *indent* 0)

(defun verilog-ident (name)
  "Convert a Lisp symbol name to a valid Verilog identifier (hyphens → underscores)."
  (substitute #\_ #\- (string name)))

(defmacro indent (&body body)
  `(let ((*indent* (1+ *indent*)))
     ,@body))

(defun emit (stream fmt &rest args)
  (dotimes (i *indent*)
    (write-char #\Space stream)
    (write-char #\Space stream))
  (apply #'format stream fmt args)
  (terpri stream))

;;; Expression emitter helpers

(defun emit-expr-binop (expr)
  "Emit a binary operation expression."
  (format nil "(~a ~a ~a)"
          (emit-expr-to-string (ir-binop-left expr))
          (let ((op (ir-binop-op expr)))
            (if (symbolp op)
                (let ((name (symbol-name op)))
                  (if (string= name "") "||" name))
                (format nil "~a" op)))
          (emit-expr-to-string (ir-binop-right expr))))

(defun emit-expr-signal-name (signal)
  "Extract and emit the Verilog identifier from a signal (may be ir-ref or symbol)."
  (verilog-ident (if (ir-ref-p signal) (ir-ref-name signal) signal)))

(defun emit-expr-partselect (expr)
  "Emit a part-select expression."
  (format stream "~a[~a:~a]"
          (emit-expr-signal-name (ir-partselect-signal expr))
          (emit-expr-to-string (ir-partselect-hi expr))
          (emit-expr-to-string (ir-partselect-lo expr))))

(defun emit-expr-to-string-partselect (expr)
  (with-output-to-string (s)
    (format s "~a[~a:~a]"
            (emit-expr-signal-name (ir-partselect-signal expr))
            (emit-expr-to-string (ir-partselect-hi expr))
            (emit-expr-to-string (ir-partselect-lo expr)))))

(defun emit-expr-concat (expr)
  "Emit a concatenation expression."
  (format nil "{~{~a~^, ~}}"
          (mapcar #'emit-expr-to-string (ir-concat-items expr))))

(defun emit-expr-funcall (expr)
  "Emit a function call expression."
  (let ((args (ir-funcall-args expr)))
    (if args
        (format nil "~a(~a)" (verilog-ident (ir-funcall-name expr))
                (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
        (format nil "~a" (verilog-ident (ir-funcall-name expr))))))

(defun emit-expr-high-z (expr)
  "Emit a high-impedance expression."
  (let ((w (ir-high-z-width expr)))
    (cond
      ((null w) "1'bz")
      ((ir-num-p w) (let ((val (ir-num-value w)))
                      (if (> val 1) (format nil "~a'bz" val) "1'bz")))
      (t (format nil "~a'bz" (emit-expr-to-string w))))))

(defun emit-expr-system-call (expr)
  "Emit a system call expression."
  (let ((args (ir-system-call-args expr)))
    (if args
        (format nil "$~a(~a)" (string-downcase (symbol-name (ir-system-call-name expr)))
                (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
        (format nil "$~a" (string-downcase (symbol-name (ir-system-call-name expr)))))))

(defun emit-expr (stream expr)
  "Emit an expression node to STREAM."
  (etypecase expr
    (ir-num (let ((val (ir-num-value expr)))
              (if (and (>= val 32) (<= val 126))
                  (format stream "~a /* ~a */" val (code-char val))
                  (format stream "~a" val))))
    (ir-str (format stream "\"~a\"" (ir-str-value expr)))
    (ir-ref (let ((name (ir-ref-name expr)))
              (if (and (symbolp name) (> (length (symbol-name name)) 0) (char= (char (symbol-name name) 0) #\$))
                  (format stream "~a" (string-downcase (symbol-name name)))
                  (format stream "~a" (verilog-ident name)))))
    (ir-binop (format stream "~a" (emit-expr-binop expr)))
    (ir-unop (format stream "(~a~a)"
                     (ir-unop-op expr)
                     (emit-expr-to-string (ir-unop-arg expr))))
    (ir-bitselect (format stream "~a[~a]"
                          (emit-expr-signal-name (ir-bitselect-signal expr))
                          (emit-expr-to-string (ir-bitselect-index expr))))
    (ir-partselect (format stream "~a" (emit-expr-to-string-partselect expr)))
    (ir-concat (format stream "~a" (emit-expr-concat expr)))
    (ir-funcall (format stream "~a" (emit-expr-funcall expr)))
    (ir-if-expr (format stream "(~a ? ~a : ~a)"
                        (emit-expr-to-string (ir-if-expr-cond expr))
                        (emit-expr-to-string (ir-if-expr-then expr))
                        (emit-expr-to-string (ir-if-expr-else expr))))
    (ir-high-z (format stream "~a" (emit-expr-high-z expr)))
    (ir-zero-extend (let ((val (emit-expr-to-string (ir-zero-extend-value expr)))
                          (tw (emit-expr-to-string (ir-zero-extend-target-width expr))))
                      (format stream "{~a'h0, ~a}" tw val)))
    (ir-sign-extend (let ((val (emit-expr-to-string (ir-sign-extend-value expr)))
                          (tw (emit-expr-to-string (ir-sign-extend-target-width expr))))
                      (format stream "{{~a{~a[~a-1]}}, ~a}" tw val tw val)))
    (ir-system-call (format stream "~a" (emit-expr-system-call expr)))))

(defun emit-expr-to-string (expr)
  "Emit an expression to a string and return it."
  (with-output-to-string (s)
    (emit-expr s expr)))

(defun width-range (width)
  "Return the Verilog range string for a given width, or NIL for width 1."
  (when (and width (> width 1))
    (format nil "[~a:0] " (1- width))))

(defun emit-port (stream port)
  (let ((dir (ecase (ir-port-direction port)
               (:input "input")
               (:output "output")
               (:inout "inout")))
        (range (width-range (ir-port-width port)))
        (kind (ir-port-kind port)))
    (if (and kind (eq kind :reg))
        (emit stream "~a reg ~a~a;" dir (or range "") (verilog-ident (ir-port-name port)))
        (emit stream "~a ~a~a;" dir (or range "") (verilog-ident (ir-port-name port))))))

(defun emit-signal (stream sig)
  (let ((kind (ecase (ir-signal-kind sig)
                (:wire "wire")
                (:reg "reg")))
        (range (width-range (ir-signal-width sig)))
        (attrs (ir-signal-attrs sig)))
    (when attrs
      (format stream "(* ~{~a~^, ~} *) " 
              (mapcar (lambda (a) (format nil "~a = \"~a\"" 
                                          (string-downcase (symbol-name (first a)))
                                          (string-downcase (if (symbolp (second a))
                                                               (symbol-name (second a))
                                                               (second a)))))
                      attrs)))
    (emit stream "~a ~a~a;" kind (or range "") (verilog-ident (ir-signal-name sig)))))

(defun emit-initial-block (stream signals)
  "Emit an initial block for signals with :init values."
  (let ((inits (remove-if-not #'ir-signal-init signals)))
    (when inits
      (terpri stream)
      (emit stream "initial begin")
      (dolist (s inits)
        (format stream "  ~a = ~a;~%" (verilog-ident (ir-signal-name s))
                (emit-expr-to-string (ir-signal-init s))))
      (emit stream "end"))))

(defun emit-param (stream p)
  (let ((w (ir-param-width p)))
    (if w
        (let ((wval (if (ir-num-p w) (ir-num-value w) w)))
          (emit stream "parameter ~a~a = ~a;" (width-range wval) (verilog-ident (ir-param-name p)) (emit-expr-to-string (ir-param-value p))))
        (emit stream "parameter ~a = ~a;" (verilog-ident (ir-param-name p)) (emit-expr-to-string (ir-param-value p))))))

(defun emit-localparam (stream p)
  (let ((w (ir-localparam-width p)))
    (if w
        (let ((wval (if (ir-num-p w) (ir-num-value w) w)))
          (emit stream "localparam ~a~a = ~a;" (width-range wval) (verilog-ident (ir-localparam-name p)) (emit-expr-to-string (ir-localparam-value p))))
        (emit stream "localparam ~a = ~a;" (verilog-ident (ir-localparam-name p)) (emit-expr-to-string (ir-localparam-value p))))))

(defun emit-cont-assign (stream a)
  (emit stream "assign ~a = ~a;" (verilog-ident (ir-cont-assign-lhs a)) (emit-expr-to-string (ir-cont-assign-rhs a))))

;;; Statement emitter helpers

(defun emit-stmt-case (stream stmt)
  "Emit a case statement."
  (emit stream "case (~a)" (emit-expr-to-string (ir-case-key stmt)))
  (indent
    (dolist (c (ir-case-cases stmt))
      (emit stream "~a: begin" (emit-expr-to-string (car c)))
      (indent
        (dolist (s (cdr c))
          (emit-stmt stream s)))
      (emit stream "end"))
    (when (ir-case-default stmt)
      (emit stream "default: begin")
      (indent
        (dolist (s (ir-case-default stmt))
          (emit-stmt stream s)))
      (emit stream "end")))
  (emit stream "endcase"))

(defun emit-stmt-for (stream stmt)
  "Emit a for loop statement."
  (emit stream "for (~a = ~a; ~a; ~a)"
        (emit-expr-to-string (ir-for-var stmt))
        (emit-expr-to-string (ir-for-init stmt))
        (emit-expr-to-string (ir-for-cond stmt))
        (emit-expr-to-string (ir-for-step stmt)))
  (indent
    (emit-stmt stream (ir-for-body stmt))))

(defun emit-stmt-begin (stream stmt)
  "Emit a begin/end block."
  (emit stream "begin")
  (indent
    (dolist (s (ir-begin-body stmt))
      (emit-stmt stream s)))
  (emit stream "end"))

(defun emit-stmt-call-or-syscall (stream name args fmt-str)
  "Emit a task call or system call."
  (if args
      (emit stream fmt-str (string-downcase (symbol-name name))
            (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
      (emit stream "~a;" (string-downcase (symbol-name name)))))

(defun emit-stmt (stream stmt)
  "Emit a statement (inside an always block)."
  (unless stmt (return-from emit-stmt nil))
  (etypecase stmt
    (ir-non-blocking
     (emit stream "~a <= ~a;" (emit-expr-to-string (ir-non-blocking-lhs stmt)) (emit-expr-to-string (ir-non-blocking-rhs stmt))))
    (ir-blocking
     (emit stream "~a = ~a;" (emit-expr-to-string (ir-blocking-lhs stmt)) (emit-expr-to-string (ir-blocking-rhs stmt))))
    (ir-if
     (emit stream "if (~a)" (emit-expr-to-string (ir-if-cond stmt)))
     (indent
       (emit-stmt stream (ir-if-then stmt)))
     (when (ir-if-else stmt)
       (emit stream "else")
       (indent
         (emit-stmt stream (ir-if-else stmt)))))
    (ir-case (emit-stmt-case stream stmt))
    (ir-begin (emit-stmt-begin stream stmt))
    (ir-delay
     (emit stream "#~a;" (emit-expr-to-string (ir-delay-value stmt))))
    (ir-system-call
     (let ((args (ir-system-call-args stmt)))
       (if args
           (emit stream "$~a(~a);" (string-downcase (symbol-name (ir-system-call-name stmt)))
                 (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
           (emit stream "$~a;" (string-downcase (symbol-name (ir-system-call-name stmt)))))))
    (ir-initial
     (emit stream "initial")
     (indent
       (emit-stmt stream (ir-initial-body stmt))))
    (ir-always-comb
     (emit stream "always @*")
     (indent
       (emit-stmt stream (ir-always-comb-body stmt))))
    (ir-forever
     (emit stream "forever")
     (indent
       (emit-stmt stream (ir-forever-body stmt))))
    (ir-task-call
     (emit stream "~a(~a);" (verilog-ident (ir-task-call-name stmt))
           (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string (ir-task-call-args stmt)))))
    (ir-for (emit-stmt-for stream stmt))))

(defun emit-always (stream ab)
  (let ((sensitivity (ir-always-sensitivity ab)))
    (emit stream "always @(~a)" (emit-sensitivity sensitivity))
    (indent
      (emit-stmt stream (ir-always-body ab)))))

(defun emit-always-comb (stream ab)
  (emit stream "always @*")
  (indent
    (emit-stmt stream (ir-always-comb-body ab))))

(defun emit-task (stream task)
  "Emit a task definition."
  (emit stream "task ~a;" (verilog-ident (ir-task-name task)))
  (when (ir-task-params task)
    (dolist (p (ir-task-params task))
      (emit stream "  input ~a~a;" (or (width-range (ir-port-width p)) "") (verilog-ident (ir-port-name p)))))
  (indent
    (dolist (s (ir-task-body task))
      (emit-stmt stream s)))
  (emit stream "endtask"))

(defun emit-function (stream func)
  "Emit a function definition."
  (let ((ret-width (cdr (ir-function-ret-width func))))
    (emit stream "function ~a~a;"
          (or (width-range ret-width) "")
          (verilog-ident (ir-function-name func))))
  (when (ir-function-params func)
    (dolist (p (ir-function-params func))
      (emit stream "  input ~a~a;" (or (width-range (ir-port-width p)) "") (verilog-ident (ir-port-name p)))))
  (indent
    (dolist (s (ir-function-body func))
      (emit-stmt stream s)))
  (emit stream "endfunction"))

(defun emit-sensitivity (sensitivity)
  "Emit a sensitivity list. Sensitivity is a list like ((posedge clk)) or :*."
  (with-output-to-string (s)
    (if (eq sensitivity :*)
        (format s "*")
        (loop for (edge signal) in sensitivity
              for first = t then nil
              do (unless first (format s " or "))
                 (format s "~a ~a" (string-downcase (symbol-name edge))
                         (verilog-ident signal))))))

;;; Module emitter helpers

(defun classify-module-items (items)
  "Classify module items into separate lists. Returns multiple values:
   ports params localparams signals assigns always-blocks always-comb-blocks
   instances defparams generate-ifs."
  (let ((ports '()) (params '()) (localparams '()) (signals '())
        (assigns '()) (always-blocks '()) (always-comb-blocks '())
        (instances '()) (defparams '()) (generate-ifs '()))
    (dolist (item items)
      (etypecase item
        (ir-port (push item ports))
        (ir-param (push item params))
        (ir-localparam (push item localparams))
        (ir-signal (push item signals))
        (ir-cont-assign (push item assigns))
        (ir-always (push item always-blocks))
        (ir-always-comb (push item always-comb-blocks))
        (ir-instance (push item instances))
        (ir-defparam (push item defparams))
        (ir-generate-if (push item generate-ifs))))
    (values (nreverse ports) (nreverse params) (nreverse localparams)
            (nreverse signals) (nreverse assigns)
            (nreverse always-blocks) (nreverse always-comb-blocks)
            (nreverse instances) (nreverse defparams) (nreverse generate-ifs))))

(defun emit-module-header (stream name ports)
  "Emit the module header with port list."
  (emit stream "module ~a (" (verilog-ident name))
  (loop for (p . rest) on ports
        do (let ((dir (ecase (ir-port-direction p)
                        (:input "input")
                        (:output "output")
                        (:inout "inout")))
                 (range (width-range (ir-port-width p)))
                 (kind (ir-port-kind p)))
             (if (and kind (eq kind :reg))
                 (emit stream "  ~a reg ~a~a~a" dir (or range "") (verilog-ident (ir-port-name p))
                       (if rest "," ""))
                 (emit stream "  ~a ~a~a~a" dir (or range "") (verilog-ident (ir-port-name p))
                       (if rest "," "")))))
  (emit stream ");"))

(defun emit-section (stream label emitter items)
  "Emit a labeled section of module items."
  (when items
    (terpri stream)
    (dolist (item items)
      (funcall emitter stream item))))

(defun emit-module (stream mod)
  "Emit a complete module to STREAM."
  (let ((name (ir-module-name mod))
        (tasks (ir-module-tasks mod))
        (functions (ir-module-functions mod)))
    (multiple-value-bind (ports params localparams signals assigns
                          always-blocks always-comb-blocks instances
                          defparams generate-ifs)
        (classify-module-items (ir-module-items mod))
      (emit-module-header stream name ports)
      (emit-section stream "params" #'emit-param params)
      (emit-section stream "localparams" #'emit-localparam localparams)
      (emit-section stream "signals" #'emit-signal signals)
      (emit-initial-block stream signals)
      (emit-section stream "tasks" #'emit-task tasks)
      (emit-section stream "functions" #'emit-function functions)
      (emit-section stream "assigns" #'emit-cont-assign assigns)
      (emit-section stream "always" #'emit-always always-blocks)
      (emit-section stream "always-comb" #'emit-always-comb always-comb-blocks)
      (emit-section stream "instances" #'emit-instance instances)
      (emit-section stream "defparams" #'emit-defparam defparams)
      (emit-section stream "generate-if" #'emit-generate-if generate-ifs)
      (emit stream "endmodule"))))

(defun emit-defparam (stream dp)
  "Emit a defparam statement."
  (emit stream "defparam ~a.~a = ~a;"
        (verilog-ident (ir-defparam-inst-name dp))
        (verilog-ident (ir-defparam-param-name dp))
        (emit-expr-to-string (ir-defparam-value dp))))

(defun emit-generate-item (stream item)
  "Emit a single item inside a generate-if block."
  (etypecase item
    (ir-instance (emit-instance stream item))
    (ir-cont-assign (emit-cont-assign stream item))
    (ir-always (emit-always stream item))
    (ir-always-comb (emit-always-comb stream item))))

(defun emit-generate-if (stream gi)
  "Emit a generate if block."
  (emit stream "generate")
  (emit stream "if (~a) begin" (emit-expr-to-string (ir-generate-if-cond gi)))
  (indent
    (dolist (item (ir-generate-if-then gi))
      (emit-generate-item stream item)))
  (when (ir-generate-if-else gi)
    (emit stream "end else begin")
    (indent
      (dolist (item (ir-generate-if-else gi))
        (emit-generate-item stream item))))
  (emit stream "end")
  (emit stream "endgenerate"))

(defun emit-instance (stream inst)
  "Emit a module instantiation."
  (let* ((module (ir-instance-module inst))
         (name (ir-instance-name inst))
         (params (ir-instance-params inst))
         (ports (ir-instance-ports inst))
         (mod-str (if (stringp module) module (verilog-ident module))))
    (if params
        (progn
          (format stream "~a #(" mod-str)
          (format stream "~%")
          (loop for (p . rest) on params
                do (format stream "    .~a(~a)~a~%" (verilog-ident (car p)) (emit-expr-to-string (cdr p))
                           (if rest "," "")))
          (format stream ") ~a (~%" (verilog-ident name)))
        (format stream "~a ~a (~%" mod-str (verilog-ident name)))
    (loop for (p . rest) on ports
          do (format stream "    .~a(~a)~a~%" (verilog-ident (car p)) (emit-expr-to-string (cdr p))
                     (if rest "," "")))
    (format stream ");~%")))


(defun emit-testbench (stream tb)
  "Emit a complete testbench to STREAM."
  (let ((name (ir-testbench-name tb))
        (signals '())
        (body '()))
    (dolist (item (ir-testbench-items tb))
      (etypecase item
        (ir-signal (push item signals))
        (t (push item body))))
    (setf signals (nreverse signals)
          body (nreverse body))
    (emit stream "`default_nettype none")
    (emit stream "`timescale 1ns / 1ps")
    (terpri stream)
    (emit stream "module ~a;" (verilog-ident name))
    (when signals
      (terpri stream)
      (dolist (s signals)
        (emit-signal stream s)))
    (when body
      (terpri stream)
      (dolist (item body)
        (etypecase item
          (ir-initial (emit-stmt stream item))
          (ir-always (emit-always stream item))
          (ir-always-comb (emit-stmt stream item))
          (ir-instance (emit-instance stream item)))))
    (emit stream "endmodule")))

(defun emit-cst-pin (stream name pin-num)
  "Emit a single pin constraint."
  (format stream "IO_LOC  \"~a\" ~a;~%" (verilog-ident name) pin-num)
  (format stream "IO_PORT \"~a\" IO_TYPE=LVCMOS33;~%" (verilog-ident name)))

(defun emit-cst (stream mod board)
  "Emit a Gowin CST constraint file for MOD using BOARD definitions."
  (let ((clock-pin (ir-board-clock board))
        (pins (ir-board-pins board))
        (ports (remove-if-not #'ir-port-p (ir-module-items mod))))
    (let ((pin-map (make-hash-table :test 'equal)))
      (dolist (p pins)
        (setf (gethash (string-downcase (symbol-name (car p))) pin-map) (cadr p)))
      (when clock-pin
        (let ((clk-port (find-if (lambda (p) (search "CLK" (symbol-name (ir-port-name p)) :test #'string=))
                                 ports)))
          (when clk-port
            (emit-cst-pin stream (ir-port-name clk-port) clock-pin))))
      (dolist (port ports)
        (let* ((name (ir-port-name port))
               (pin-num (gethash (string-downcase (symbol-name name)) pin-map)))
          (when pin-num
            (emit-cst-pin stream name pin-num)))))))
