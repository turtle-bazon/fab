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
    (ir-num (format stream "~a" (ir-num-value expr)))
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
                           (ir-partselect-hi expr)
                           (ir-partselect-lo expr)))
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
       (emit-stmt stream (ir-forever-body stmt))))))

(defun emit-always (stream ab)
  (let ((sensitivity (ir-always-sensitivity ab)))
    (emit stream "always @(~a)" (emit-sensitivity sensitivity))
    (indent
      (emit-stmt stream (ir-always-body ab)))))

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
        (always-blocks '()))
    ;; Classify items
    (dolist (item (ir-module-items mod))
      (etypecase item
        (ir-port (push item ports))
        (ir-param (push item params))
        (ir-localparam (push item localparams))
        (ir-signal (push item signals))
        (ir-cont-assign (push item assigns))
        (ir-always (push item always-blocks))))
    (setf ports (nreverse ports)
          params (nreverse params)
          localparams (nreverse localparams)
          signals (nreverse signals)
          assigns (nreverse assigns)
          always-blocks (nreverse always-blocks))
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
    ;; End module
    (emit stream "endmodule")))

(defun emit-instance (stream inst)
  "Emit a module instantiation."
  (let ((module (ir-instance-module inst))
        (name (ir-instance-name inst))
        (params (ir-instance-params inst))
        (ports (ir-instance-ports inst)))
    (if params
        (format stream "~a #(" (verilog-ident module))
        (format stream "~a " (verilog-ident module)))
    (when params
      (format stream "~%")
      (loop for (p . rest) on params
            do (format stream "    .~a(~a)~a~%" (verilog-ident (car p)) (emit-expr-to-string (cdr p))
                       (if rest "," ""))))
    (format stream ") ~a (~%" (verilog-ident name))
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
