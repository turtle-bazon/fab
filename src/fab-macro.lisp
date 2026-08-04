(in-package :fab)

;;; Output directory — where generated Verilog is written.

(defparameter *output-dir* "build"
  "Directory for generated Verilog files. Defaults to \"build\".
Set to a different path to redirect output: (let ((*output-dir* \"rtl\")) ...)")

;;; Known function names for implicit funcall detection (set during module parsing)

(defvar *current-functions* nil
  "List of function names defined in the current module, used for implicit funcall detection.")

;;; Helper: compare symbol name to a string (package-safe)

(defun sym-name (sym)
  "Return the symbol name string, uppercased."
  (symbol-name sym))



;;; Expression parser

(defun parse-expr (form)
  "Parse a DSL expression form into an IR expression node."
  (cond
    ((numberp form) (ir-num form))
    ((characterp form) (ir-num (char-code form)))
    ((stringp form) (ir-str form))
    ((symbolp form) (ir-ref form))
    ((listp form)
     (let ((op (sym-name (car form))))
       (cond
         ((string= op "+") (ir-binop '+ (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "-") (ir-binop '- (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "*") (ir-binop '* (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "/") (ir-binop '/ (parse-expr (second form)) (parse-expr (third form))))
         ((or (string= op "=") (string= op "EQ")) (ir-binop '== (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "/=") (ir-binop '!= (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "<") (ir-binop '< (parse-expr (second form)) (parse-expr (third form))))
         ((string= op ">") (ir-binop '> (parse-expr (second form)) (parse-expr (third form))))
         ((string= op "<=") (ir-binop '<= (parse-expr (second form)) (parse-expr (third form))))
         ((string= op ">=") (ir-binop '>= (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "AND") (ir-binop '&& (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "OR") (ir-binop '|| (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "LOGAND") (ir-binop '& (parse-expr (second form)) (parse-expr (third form))))
           ((string= op "LOGOR") (ir-binop '\| (parse-expr (second form)) (parse-expr (third form))))
           ((string= op "LOGXOR") (ir-binop '^ (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "NOT") (ir-unop '! (parse-expr (second form))))
          ((string= op "LOGNOT") (ir-unop '~ (parse-expr (second form))))
          ((string= op "SLICE") (ir-partselect (parse-expr (second form))
                                               (parse-expr (third form))
                                               (parse-expr (fourth form))))
          ((string= op "CONCAT")
           (ir-concat (mapcar #'parse-expr (cdr form))))
          ((string= op "BIT") (ir-bitselect (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "IF")
           (ir-if-expr (parse-expr (second form))
                       (parse-expr (third form))
                       (parse-expr (fourth form))))
          ((string= op "FUNCALL") (ir-funcall (second form) (mapcar #'parse-expr (cddr form))))
          ((char= (char op 0) #\$) (ir-system-call (intern (subseq op 1)) (mapcar #'parse-expr (cdr form))))
          ;; Implicit function call: if first element matches a known function name
          ((and *current-functions* (member (car form) *current-functions* :test #'string=))
           (ir-funcall (car form) (mapcar #'parse-expr (cdr form))))
          (t (error "Unknown expression form: ~a" form)))))
    (t (error "Invalid expression: ~a" form))))

;;; Statement parser

(defun parse-stmt (form &optional task-names)
  "Parse a DSL statement form into an IR statement node.
   TASK-NAMES is a list of known task names for implicit call detection."
  (cond
    ((listp form)
     (let ((op (sym-name (car form))))
       (cond
          ((or (string= op "<=") (string= op "SETF-NB"))
           (ir-non-blocking (parse-expr (second form)) (parse-expr (third form))))
          ((or (string= op "=") (string= op "SETF"))
           (ir-blocking (parse-expr (second form)) (parse-expr (third form))))
          ((string= op "INCF")
           (ir-blocking (parse-expr (second form))
                        (ir-binop '+ (parse-expr (second form))
                                 (if (third form) (parse-expr (third form)) (ir-num 1)))))
          ((string= op "DECF")
           (ir-blocking (parse-expr (second form))
                        (ir-binop '- (parse-expr (second form))
                                 (if (third form) (parse-expr (third form)) (ir-num 1)))))
          ((string= op "INCF-NB")
           (ir-non-blocking (parse-expr (second form))
                            (ir-binop '+ (parse-expr (second form))
                                     (if (third form) (parse-expr (third form)) (ir-num 1)))))
          ((string= op "DECF-NB")
           (ir-non-blocking (parse-expr (second form))
                            (ir-binop '- (parse-expr (second form))
                                     (if (third form) (parse-expr (third form)) (ir-num 1)))))
          ((string= op "IF") (ir-if (parse-expr (second form))
                                    (parse-stmt (third form) task-names)
                                    (when (fourth form) (parse-stmt (fourth form) task-names))))
          ((string= op "CASE") (parse-case form task-names))
          ((string= op "FOR")
           (let ((var-form (second form))
                 (cond-expr (third form))
                 (step (fourth form))
                 (body (cdddr (cddr form))))
             (ir-for (parse-expr (first var-form))
                     (parse-expr (second var-form))
                     (parse-expr cond-expr)
                     (parse-expr step)
                     (ir-begin (mapcar #'(lambda (s) (parse-stmt s task-names)) body)))))
          ((string= op "BEGIN") (ir-begin (mapcar #'(lambda (s) (parse-stmt s task-names)) (cdr form))))
         ((string= op "INITIAL") (ir-initial (ir-begin (mapcar #'(lambda (s) (parse-stmt s task-names)) (cdr form)))))
         ((string= op "FOREVER") (ir-forever (parse-stmt (second form) task-names)))
         ((string= op "DELAY") (ir-delay (parse-expr (second form))))
         ((string= op "CALL") (ir-task-call (second form) (mapcar #'parse-expr (cddr form))))
         ((string= op "FUNCALL") (ir-funcall (second form) (mapcar #'parse-expr (cddr form))))
         ((char= (char op 0) #\$) (ir-system-call (intern (subseq op 1)) (mapcar #'parse-expr (cdr form))))
         ;; Implicit task call: if first element matches a known task name
         ((and task-names (member (car form) task-names :test #'string=))
          (ir-task-call (car form) (mapcar #'parse-expr (cdr form))))
         (t (error "Unknown statement form: ~a" form)))))
    (t (error "Invalid statement: ~a" form))))

;;; Case parser

(defun parse-case (form &optional task-names)
  "Parse a DSL case form into an IR case node."
  (let ((key (second form))
        (items (cddr form)))
    (let ((cases '())
          (default '()))
      (dolist (item items)
        (if (and (symbolp (car item))
                 (string= (sym-name (car item)) "OTHERWISE"))
            (setf default (mapcar #'(lambda (s) (parse-stmt s task-names)) (cdr item)))
            (push (cons (parse-expr (car item))
                        (mapcar #'(lambda (s) (parse-stmt s task-names)) (cdr item)))
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

(defun parse-always (form &optional task-names)
  "Parse a DSL always form into an IR always block."
  (let ((sensitivity (second form))
        (body (cddr form)))
    (ir-always (parse-sensitivity sensitivity)
               (ir-begin (mapcar #'(lambda (s) (parse-stmt s task-names)) body)))))

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
  "Parse a DSL signal form: (name kind width) or (name kind width :attrs ... :init val).
   Width is optional — if the third element is a keyword, width is nil."
  (let ((name (first form))
        (kind (second form))
        (width nil)
        (attrs nil)
        (init nil)
        (keyword-start nil))
    ;; If third element is not a keyword, it's the width
    (if (and (third form) (not (keywordp (third form))))
        (progn (setf width (third form))
               (setf keyword-start (cdddr form)))  ; keywords start at position 4
        (setf keyword-start (cddr form)))           ; keywords start at position 3
    ;; Check for keyword arguments
    (loop for rest on keyword-start by #'cddr
          when (and (keywordp (car rest))
                    (string= (symbol-name (car rest)) "ATTRS"))
          do (setf attrs (second rest))
          when (and (keywordp (car rest))
                    (string= (symbol-name (car rest)) "INIT"))
          do (setf init (parse-expr (second rest))))
    (ir-signal name kind width attrs init)))

(defun parse-assign (form)
  "Parse a DSL continuous assign form: (lhs rhs)."
  (ir-cont-assign (first form) (parse-expr (second form))))

;;; Task parser

(defun parse-task (form &optional task-names)
  "Parse a DSL task form: (name ((param-name kind width) ...) body...)."
  (let ((name (first form))
        (params (second form))
        (body (cddr form)))
    (ir-task name
             (mapcar (lambda (p) (ir-port (first p) (second p) (third p))) params)
             (mapcar #'(lambda (s) (parse-stmt s task-names)) body))))

;;; Function parser

(defun parse-function (form)
  "Parse a DSL function form: (name ((param-name kind width) ...) :returns kind width :body (...))."
  (let ((name (first form))
        (params (second form))
        (opts (cddr form))
        (ret-kind nil)
        (ret-width nil)
        (body nil))
    (loop for (key val) on opts by #'cddr
          when (and (keywordp key) (string= (symbol-name key) "RETURNS"))
          do (setf ret-kind (first val) ret-width (second val))
          when (and (keywordp key) (string= (symbol-name key) "BODY"))
          do (setf body (mapcar #'parse-stmt val)))
    (ir-function name
                 (mapcar (lambda (p) (ir-port (first p) (second p) (third p))) params)
                 (cons ret-kind ret-width)
                 body)))

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
                                                  ((string= tag "ALWAYS-COMB")
                                                   (ir-always-comb
                                                    (ir-begin (mapcar #'(lambda (s) (parse-stmt s)) (cdr item)))))
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
          (tasks '())
          (functions '())
          (body '())
          (board nil))
      (loop for (key val) on opts by #'cddr
            do                  (let ((key-name (sym-name key)))
                    (cond
                      ((string= key-name "PORTS") (setf ports (mapcar #'parse-port val)))
                      ((string= key-name "PARAMS") (setf params (mapcar #'parse-param val)))
                      ((string= key-name "LOCALPARAMS") (setf localparams (mapcar #'parse-localparam val)))
                      ((string= key-name "SIGNALS") (setf signals (mapcar #'parse-signal val)))
                      ((string= key-name "ASSIGNS") (setf assigns (mapcar #'parse-assign val)))
                      ((string= key-name "TASKS")
                       (let ((task-names (mapcar #'first val))
                             (*current-functions* (mapcar #'ir-function-name functions)))
                         (setf tasks (mapcar #'(lambda (f) (parse-task f task-names)) val))))
                      ((string= key-name "FUNCTIONS") (setf functions (mapcar #'parse-function val)))
                      ((string= key-name "BOARD") (setf board (if (keywordp val) val (intern (string-upcase (symbol-name val)) :keyword))))
                      ((string= key-name "BODY")
                       (let ((task-names (mapcar #'ir-task-name tasks))
                             (*current-functions* (mapcar #'ir-function-name functions)))
                         (setf body (mapcar #'(lambda (item)
                                               (let ((tag (sym-name (car item))))
                                               (cond
                                                     ((string= tag "ALWAYS") (parse-always item task-names))
                                                     ((string= tag "ALWAYS-COMB")
                                                      (ir-always-comb
                                                       (ir-begin (mapcar #'(lambda (s) (parse-stmt s task-names)) (cdr item)))))
                                                     ((string= tag "INSTANCE") (parse-instance item))
                                                     (t (error "Unknown body item: ~a" item)))))
                                           val))))
                      (t (error "Unknown module option: ~a" key)))))
      (ir-module name board (append ports params localparams signals assigns body) tasks functions))))

;;; Board parser

(defun parse-board (form)
  "Parse a DSL board form into an IR board."
  (let ((name (second form))
        (opts (cddr form)))
    (let ((device nil)
          (family nil)
          (clock nil)
          (pins '()))
      (loop for (key val) on opts by #'cddr
            do (let ((key-name (sym-name key)))
                 (cond
                   ((string= key-name "DEVICE") (setf device val))
                   ((string= key-name "FAMILY") (setf family val))
                   ((string= key-name "CLOCK") (setf clock val))
                   ((string= key-name "PINS") (setf pins val))
                   (t (error "Unknown board option: ~a" key)))))
      (ir-board name device family clock pins))))

;;; Top-level entry point

(defvar *boards* (make-hash-table :test 'equal)
  "Registry of defined boards.")

(defun fab-impl (mod-form)
  "Parse a module, testbench, or board form, emit Verilog/CST, write to *output-dir*/<name>."
  (let ((kind (sym-name (car mod-form))))
    (cond
      ((string= kind "BOARD")
       (let ((board (parse-board mod-form)))
         (setf (gethash (symbol-name (ir-board-name board)) *boards*) board)
         (format t "Defined board ~a~%" (ir-board-name board))
         nil))
      ((string= kind "MODULE")
       (let ((mod (parse-module mod-form)))
         (ensure-directories-exist *output-dir*)
         (let ((outfile (format nil "~a/~a.v" *output-dir* (verilog-ident (ir-module-name mod)))))
           (with-open-file (s outfile :direction :output :if-exists :supersede)
             (emit-module s mod))
           (format t "Emitted ~a~%" outfile)
           ;; Generate CST if board is specified
           (let ((board-name (ir-module-board mod)))
             (when board-name
               (let ((board (gethash (if (symbolp board-name)
                                         (symbol-name board-name)
                                         board-name)
                                     *boards*)))
                 (when board
                   (let ((cstfile (format nil "~a/~a.cst" *output-dir*
                                          (verilog-ident (ir-module-name mod)))))
                     (with-open-file (s cstfile :direction :output :if-exists :supersede)
                       (emit-cst s mod board))
                     (format t "Emitted ~a~%" cstfile))))))
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
