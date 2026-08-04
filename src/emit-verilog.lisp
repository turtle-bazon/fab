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
    (ir-binop (format stream "(~a ~a ~a)"
                      (emit-expr-to-string (ir-binop-left expr))
                      (ir-binop-op expr)
                      (emit-expr-to-string (ir-binop-right expr))))
    (ir-unop (format stream "(~a~a)"
                     (ir-unop-op expr)
                     (emit-expr-to-string (ir-unop-arg expr))))
    (ir-bitselect (format stream "~a[~a]"
                          (verilog-ident (if (ir-ref-p (ir-bitselect-signal expr))
                                            (ir-ref-name (ir-bitselect-signal expr))
                                            (ir-bitselect-signal expr)))
                          (emit-expr-to-string (ir-bitselect-index expr))))
    (ir-partselect (format stream "~a[~a:~a]"
                           (verilog-ident (if (ir-ref-p (ir-partselect-signal expr))
                                             (ir-ref-name (ir-partselect-signal expr))
                                             (ir-partselect-signal expr)))
                           (emit-expr-to-string (ir-partselect-hi expr))
                           (emit-expr-to-string (ir-partselect-lo expr))))
    (ir-concat (format stream "{~{~a~^, ~}}"
                       (mapcar #'emit-expr-to-string (ir-concat-items expr))))
    (ir-funcall
     (let ((args (ir-funcall-args expr)))
       (if args
           (format stream "~a(~a)" (verilog-ident (ir-funcall-name expr))
                   (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
           (format stream "~a" (verilog-ident (ir-funcall-name expr))))))
    (ir-if-expr (format stream "(~a ? ~a : ~a)"
                        (emit-expr-to-string (ir-if-expr-cond expr))
                        (emit-expr-to-string (ir-if-expr-then expr))
                        (emit-expr-to-string (ir-if-expr-else expr))))
    (ir-system-call
     (let ((args (ir-system-call-args expr)))
       (if args
           (format stream "$~a(~a)" (string-downcase (symbol-name (ir-system-call-name expr)))
                   (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
           (format stream "$~a" (string-downcase (symbol-name (ir-system-call-name expr)))))))))

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
               (:output "output")))
        (range (width-range (ir-port-width port))))
    (emit stream "~a ~a~a;" dir (or range "") (verilog-ident (ir-port-name port)))))

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
  (emit stream "parameter ~a = ~a;" (verilog-ident (ir-param-name p)) (emit-expr-to-string (ir-param-value p))))

(defun emit-localparam (stream p)
  (emit stream "localparam ~a = ~a;" (verilog-ident (ir-localparam-name p)) (emit-expr-to-string (ir-localparam-value p))))

(defun emit-cont-assign (stream a)
  (emit stream "assign ~a = ~a;" (verilog-ident (ir-cont-assign-lhs a)) (emit-expr-to-string (ir-cont-assign-rhs a))))

(defun emit-stmt (stream stmt)
  "Emit a statement (inside an always block)."
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
    (ir-case
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
    (ir-begin
     (emit stream "begin")
     (indent
       (dolist (s (ir-begin-body stmt))
         (emit-stmt stream s)))
     (emit stream "end"))
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
     (let ((args (ir-task-call-args stmt)))
       (if args
           (emit stream "~a(~a);" (verilog-ident (ir-task-call-name stmt))
                 (format nil "~{~a~^, ~}" (mapcar #'emit-expr-to-string args)))
           (emit stream "~a;" (verilog-ident (ir-task-call-name stmt))))))
    (ir-for
     (emit stream "for (~a = ~a; ~a; ~a)"
           (emit-expr-to-string (ir-for-var stmt))
           (emit-expr-to-string (ir-for-init stmt))
           (emit-expr-to-string (ir-for-cond stmt))
           (emit-expr-to-string (ir-for-step stmt)))
     (indent
       (emit-stmt stream (ir-for-body stmt))))))

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
              do (unless first (format s " "))
                 (format s "~a ~a" (string-downcase (symbol-name edge))
                         (verilog-ident signal))))))

(defun emit-module (stream mod)
  "Emit a complete module to STREAM."
    (let ((name (ir-module-name mod))
        (ports '())
        (params '())
        (localparams '())
        (signals '())
        (assigns '())
        (always-blocks '())
        (always-comb-blocks '())
        (instances '())
        (tasks (ir-module-tasks mod))
        (functions (ir-module-functions mod)))
    ;; Classify items
    (dolist (item (ir-module-items mod))
      (etypecase item
        (ir-port (push item ports))
        (ir-param (push item params))
        (ir-localparam (push item localparams))
        (ir-signal (push item signals))
        (ir-cont-assign (push item assigns))
        (ir-always (push item always-blocks))
        (ir-always-comb (push item always-comb-blocks))
        (ir-instance (push item instances))))
    (setf ports (nreverse ports)
          params (nreverse params)
          localparams (nreverse localparams)
          signals (nreverse signals)
          assigns (nreverse assigns)
          always-blocks (nreverse always-blocks)
          always-comb-blocks (nreverse always-comb-blocks)
          instances (nreverse instances))
    ;; Module header
    (emit stream "module ~a (" (verilog-ident name))
    (loop for (p . rest) on ports
          do (let ((dir (ecase (ir-port-direction p)
                          (:input "input")
                          (:output "output")))
                   (range (width-range (ir-port-width p))))
               (emit stream "  ~a ~a~a~a" dir (or range "") (verilog-ident (ir-port-name p))
                     (if rest "," ""))))
    (emit stream ");")
    ;; Parameters
    (when params
      (terpri stream)
      (dolist (p params)
        (emit-param stream p)))
    ;; Localparams
    (when localparams
      (terpri stream)
      (dolist (p localparams)
        (emit-localparam stream p)))
    ;; Signals
    (when signals
      (terpri stream)
      (dolist (s signals)
        (emit-signal stream s)))
    ;; Initial values
    (emit-initial-block stream signals)
    ;; Tasks
    (when tasks
      (terpri stream)
      (dolist (task tasks)
        (emit-task stream task)))
    ;; Functions
    (when functions
      (terpri stream)
      (dolist (func functions)
        (emit-function stream func)))
    ;; Continuous assigns
    (when assigns
      (terpri stream)
      (dolist (a assigns)
        (emit-cont-assign stream a)))
    ;; Always blocks
    (when always-blocks
      (terpri stream)
      (dolist (ab always-blocks)
        (emit-always stream ab)))
    ;; Always combinational blocks
    (when always-comb-blocks
      (terpri stream)
      (dolist (ab always-comb-blocks)
        (emit-always-comb stream ab)))
    ;; Instances
    (when instances
      (terpri stream)
      (dolist (inst instances)
        (emit-instance stream inst)))
    ;; End module
    (emit stream "endmodule")))

(defun emit-instance (stream inst)
  "Emit a module instantiation."
  (let ((module (ir-instance-module inst))
        (name (ir-instance-name inst))
        (params (ir-instance-params inst))
        (ports (ir-instance-ports inst)))
    (if params
        (progn
          (format stream "~a #(" (verilog-ident module))
          (format stream "~%")
          (loop for (p . rest) on params
                do (format stream "    .~a(~a)~a~%" (verilog-ident (car p)) (emit-expr-to-string (cdr p))
                           (if rest "," "")))
          (format stream ") ~a (~%" (verilog-ident name)))
        (format stream "~a ~a (~%" (verilog-ident module) (verilog-ident name)))
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

(defun emit-cst (stream mod board)
  "Emit a Gowin CST constraint file for MOD using BOARD definitions."
  (let ((clock-pin (ir-board-clock board))
        (pins (ir-board-pins board))
        (ports (remove-if-not #'ir-port-p (ir-module-items mod))))
    ;; Map port names to pin numbers
    (let ((pin-map (make-hash-table :test 'equal)))
      (dolist (p pins)
        (setf (gethash (string-downcase (symbol-name (car p))) pin-map) (cadr p)))
      ;; Emit clock constraint
      (when clock-pin
        (let ((clk-port (find-if (lambda (p) (string= (symbol-name (ir-port-name p)) "CLK"))
                                 ports)))
          (when clk-port
            (format stream "IO_LOC  \"~a\" ~a;~%" (verilog-ident (ir-port-name clk-port)) clock-pin))))
      ;; Emit other pin constraints
      (dolist (port ports)
        (let* ((name (ir-port-name port))
               (pin-num (gethash (string-downcase (symbol-name name)) pin-map)))
          (when pin-num
            (format stream "IO_LOC  \"~a\" ~a;~%" (verilog-ident name) pin-num)))))))
