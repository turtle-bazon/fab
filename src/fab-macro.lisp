(in-package :fab)

;;; Output directory — where generated Verilog is written.

(defparameter *output-dir* "build"
  "Directory for generated Verilog files. Defaults to \"build\".
Set to a different path to redirect output: (let ((*output-dir* \"rtl\")) ...)")

;;; Helper: compare symbol name to a string (package-safe)

(defun sym-name (sym)
  "Return the symbol name string, uppercased."
  (symbol-name sym))



;;; Expression parser

(defun parse-expr (form)
  "Parse a DSL expression form into an IR expression node."
  (cond
    ((numberp form) (ir-num form))
    ((stringp form) (ir-str form))
    ((symbolp form) (ir-ref form))
    ((listp form)
     (let ((op (sym-name (car form))))
       (cond
         ((string= op "+") (ir-binop '+ (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "-") (ir-binop '- (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "*") (ir-binop '* (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "/") (ir-binop '/ (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "=") (ir-binop '== (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "/=") (ir-binop '!= (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "<") (ir-binop '< (parse-expr (second form)) (parse-expr (third form))))
         ((string= op ">") (ir-binop '> (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "<=") (ir-binop '<= (parse-expr (second form)) (parse-expr (third form))))
         ((string= op ">=") (ir-binop '>= (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "AND") (ir-binop '&& (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "OR") (ir-binop '|| (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "NOT") (ir-unop '! (parse-expr (second form))))
          ((string= op "BIT") (ir-bitselect (parse-expr (second form)) (parse-expr (third form))))
          ((char= (char op 0) #\$) (ir-system-call (intern (subseq op 1)) (mapcar #'parse-expr (cdr form))))
          (t (error "Unknown expression form: ~a" form)))))
    (t (error "Invalid expression: ~a" form))))

;;; Statement parser

(defun parse-stmt (form)
  "Parse a DSL statement form into an IR statement node."
  (cond
    ((listp form)
     (let ((op (sym-name (car form))))
       (cond
         ((string= op "<=") (ir-non-blocking (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "=") (ir-blocking (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "IF") (ir-if (parse-expr (second form))
                                   (parse-stmt (third form))
                                   (when (fourth form) (parse-stmt (fourth form)))))
         ((string= op "CASE") (parse-case form))
         ((string= op "BEGIN") (ir-begin (mapcar #'parse-stmt (cdr form))))
         ((string= op "INITIAL") (ir-initial (ir-begin (mapcar #'parse-stmt (cdr form)))))
         ((string= op "FOREVER") (ir-forever (parse-stmt (second form))))
         ((string= op "DELAY") (ir-delay (parse-expr (second form))))
         ((char= (char op 0) #\$) (ir-system-call (intern (subseq op 1)) (mapcar #'parse-expr (cdr form))))
         (t (error "Unknown statement form: ~a" form)))))
    (t (error "Invalid statement: ~a" form))))

;;; Case parser

(defun parse-case (form)
  "Parse a DSL case form into an IR case node."
  (let ((key (second form))
        (items (cddr form)))
    (let ((cases '())
          (default '()))
      (dolist (item items)
        (if (and (symbolp (car item))
                 (string= (sym-name (car item)) "OTHERWISE"))
            (setf default (mapcar #'parse-stmt (cdr item)))
            (push (cons (parse-expr (car item))
                        (mapcar #'parse-stmt (cdr item)))
                  cases)))
      (ir-case (parse-expr key) (nreverse cases) default))))

;;; Sensitivity parser

(defun parse-sensitivity (form)
  "Parse a DSL sensitivity list form."
  (cond
    ((and (listp form) (= (length form) 2))
     (list (list (first form) (second form))))
    ((and (symbolp form) (string= (sym-name form) "*"))
     :*)
    (t (error "Invalid sensitivity list: ~a" form))))

;;; Always parser

(defun parse-always (form)
  "Parse a DSL always form into an IR always block."
  (let ((sensitivity (second form))
        (body (cddr form)))
    (ir-always (parse-sensitivity sensitivity)
               (ir-begin (mapcar #'parse-stmt body)))))

;;; Item parsers

(defun parse-port (form)
  "Parse a DSL port form: (name direction width)."
  (ir-port (first form) (second form) (third form)))

(defun parse-param (form)
  "Parse a DSL param form: (name value)."
  (ir-param (first form) (parse-expr (second form))))

(defun parse-localparam (form)
  "Parse a DSL localparam form: (name value)."
  (ir-localparam (first form) (parse-expr (second form))))

(defun parse-signal (form)
  "Parse a DSL signal form: (name kind width) or (name kind width :attrs ((key val) ...))."
  (let ((name (first form))
        (kind (second form))
        (width (third form))
        (attrs nil))
    ;; Check for :attrs keyword
    (loop for rest on (cdddr form) by #'cddr
          when (and (keywordp (car rest))
                    (string= (symbol-name (car rest)) "ATTRS"))
          do (setf attrs (second rest)))
    (ir-signal name kind width attrs)))

(defun parse-assign (form)
  "Parse a DSL continuous assign form: (lhs rhs)."
  (ir-cont-assign (first form) (parse-expr (second form))))

;;; Instance parser

(defun parse-instance (form)
  "Parse a DSL instance form: (instance module (inst-name) (params...) (ports...))."
  (let ((module (second form))
        (inst-name (first (third form)))
        (params (fourth form))
        (ports (fifth form)))
    (ir-instance module inst-name
                 (mapcar (lambda (p) (cons (first p) (parse-expr (second p)))) params)
                 (mapcar (lambda (p) (cons (first p) (parse-expr (second p)))) ports))))

;;; Testbench parser

(defun parse-testbench (form)
  "Parse a DSL testbench form into an IR testbench."
  (let ((name (second form))
        (opts (cddr form)))
    (let ((signals '())
          (body '()))
      (loop for (key val) on opts by #'cddr
            do (let ((key-name (sym-name key)))
                 (cond
                   ((string= key-name "SIGNALS") (setf signals (mapcar #'parse-signal val)))
                   ((string= key-name "BODY")
                    (setf body (mapcar #'(lambda (item)
                                           (let ((tag (sym-name (car item))))
                                             (cond
                                               ((string= tag "INITIAL") (parse-stmt item))
                                               ((string= tag "ALWAYS") (parse-always item))
                                               ((string= tag "INSTANCE") (parse-instance item))
                                               (t (error "Unknown testbench body item: ~a" item)))))
                                       val)))
                   (t (error "Unknown testbench option: ~a" key)))))
      (ir-testbench name (append signals body)))))

;;; Module parser

(defun parse-module (form)
  "Parse a DSL module form into an IR module."
  (let ((name (second form))
        (opts (cddr form)))
    (let ((ports '())
          (params '())
          (localparams '())
          (signals '())
          (assigns '())
          (body '()))
      (loop for (key val) on opts by #'cddr
            do                  (let ((key-name (sym-name key)))
                   (cond
                     ((string= key-name "PORTS") (setf ports (mapcar #'parse-port val)))
                     ((string= key-name "PARAMS") (setf params (mapcar #'parse-param val)))
                     ((string= key-name "LOCALPARAMS") (setf localparams (mapcar #'parse-localparam val)))
                     ((string= key-name "SIGNALS") (setf signals (mapcar #'parse-signal val)))
                     ((string= key-name "ASSIGNS") (setf assigns (mapcar #'parse-assign val)))
                     ((string= key-name "BODY")
                      (setf body (mapcar #'(lambda (item)
                                            (let ((tag (sym-name (car item))))
                                              (cond
                                                ((string= tag "ALWAYS") (parse-always item))
                                                (t (error "Unknown body item: ~a" item)))))
                                        val)))
                     (t (error "Unknown module option: ~a" key)))))
      (ir-module name (append ports params localparams signals assigns body)))))

;;; Top-level entry point

(defun fab-impl (mod-form)
  "Parse a module or testbench form, emit Verilog, write to *output-dir*/<name>.v."
  (let ((kind (sym-name (car mod-form))))
    (cond
      ((string= kind "MODULE")
       (let ((mod (parse-module mod-form)))
         (ensure-directories-exist *output-dir*)
         (let ((outfile (format nil "~a/~a.v" *output-dir* (verilog-ident (ir-module-name mod)))))
           (with-open-file (s outfile :direction :output :if-exists :supersede)
             (emit-module s mod))
           (format t "Emitted ~a~%" outfile)
           outfile)))
      ((string= kind "TESTBENCH")
       (let ((tb (parse-testbench mod-form)))
         (ensure-directories-exist *output-dir*)
         (let ((outfile (format nil "~a/~a.v" *output-dir* (verilog-ident (ir-testbench-name tb)))))
           (with-open-file (s outfile :direction :output :if-exists :supersede)
             (emit-testbench s tb))
           (format t "Emitted ~a~%" outfile)
           outfile)))
      (t (error "Unknown top-level form: ~a" kind)))))

;;; The (fab) macro

(defmacro fab (&body body)
  "Top-level macro. Usage: (fab (module name :ports ... :body ...)) or (fab (testbench name :body ...))"
  (let ((mod-form (car body)))
    `(fab-impl ',mod-form)))
