(defpackage :fab-test
  (:use :cl :fiveam)
  (:import-from :fab #:ir-board-device #:ir-board-family #:ir-board-clock #:ir-board-pins)
  (:export #:run-tests))

(in-package :fab-test)

(def-suite fab-suite
  :description "Tests for (fab) DSL parser and emitter")

(in-suite fab-suite)

;;; Helper: emit IR to string

(defun emit-to-string (emitter ir)
  (with-output-to-string (s)
    (funcall emitter s ir)))

;;; Expression parser tests

(test parse-number
  (let ((ir (fab::parse-expr 42)))
    (is (fab::ir-num-p ir))
    (is (= 42 (fab::ir-num-value ir)))))

(test parse-char
  (let ((ir (fab::parse-expr #\U)))
    (is (fab::ir-num-p ir))
    (is (= 85 (fab::ir-num-value ir)))))

(test parse-string
  (let ((ir (fab::parse-expr "hello")))
    (is (fab::ir-str-p ir))
    (is (string= "hello" (fab::ir-str-value ir)))))

(test parse-symbol
  (let ((ir (fab::parse-expr 'my-signal)))
    (is (fab::ir-ref-p ir))
    (is (eq 'my-signal (fab::ir-ref-name ir)))))

(test parse-binop
  (let ((ir (fab::parse-expr '(+ a b))))
    (is (fab::ir-binop-p ir))
    (is (eq '+ (fab::ir-binop-op ir)))
    (is (fab::ir-ref-p (fab::ir-binop-left ir)))
    (is (fab::ir-ref-p (fab::ir-binop-right ir)))))

(test parse-unop
  (let ((ir (fab::parse-expr '(lognot x))))
    (is (fab::ir-unop-p ir))
    (is (eq 'fab::~ (fab::ir-unop-op ir)))))

(test parse-slice
  (let ((ir (fab::parse-expr '(slice data 7 0))))
    (is (fab::ir-partselect-p ir))
    (is (eq 'data (fab::ir-ref-name (fab::ir-partselect-signal ir))))))

(test parse-concat
  (let ((ir (fab::parse-expr '(concat a b c))))
    (is (fab::ir-concat-p ir))
    (is (= 3 (length (fab::ir-concat-items ir))))))

(test parse-if-expr
  (let ((ir (fab::parse-expr '(if sel a b))))
    (is (fab::ir-if-expr-p ir))))

(test parse-high-z
  (let ((ir (fab::parse-expr '(high-z 8))))
    (is (fab::ir-high-z-p ir))
    (is (fab::ir-num-p (fab::ir-high-z-width ir)))))

(test parse-zero-extend
  (let ((ir (fab::parse-expr '(zero-extend val 16))))
    (is (fab::ir-zero-extend-p ir))))

(test parse-sign-extend
  (let ((ir (fab::parse-expr '(sign-extend val 16))))
    (is (fab::ir-sign-extend-p ir))))

;;; Expression emitter tests

(test emit-number
  (let ((result (emit-to-string #'fab::emit-expr (fab::ir-num 42))))
    (is (search "42" result))))

(test emit-number-char
  (let ((result (emit-to-string #'fab::emit-expr (fab::ir-num 85))))
    (is (search "85" result))
    (is (search "U" result))))

(test emit-string
  (is (string= "\"hello\"" (emit-to-string #'fab::emit-expr (fab::ir-str "hello")))))

(test emit-ref
  (is (string= "MY_SIGNAL" (emit-to-string #'fab::emit-expr (fab::ir-ref 'my-signal)))))

(test emit-binop
  (let* ((ir (fab::parse-expr '(+ a b)))
         (result (emit-to-string #'fab::emit-expr ir)))
    (is (search "+" result))
    (is (search "A" result))
    (is (search "B" result))))

(test emit-partselect
  (let* ((ir (fab::parse-expr '(slice data 7 0)))
         (result (emit-to-string #'fab::emit-expr ir)))
    (is (search "DATA" result))
    (is (search "[7:0]" result))))

(test emit-concat
  (let* ((ir (fab::parse-expr '(concat a b)))
         (result (emit-to-string #'fab::emit-expr ir)))
    (is (search "{" result))
    (is (search "}" result))
    (is (search "," result))))

(test emit-high-z
  (let ((result (emit-to-string #'fab::emit-expr (fab::ir-high-z (fab::ir-num 8)))))
    (is (search "bz" result))))

(test emit-high-z-1bit
  (let ((result (emit-to-string #'fab::emit-expr (fab::ir-high-z nil))))
    (is (string= "1'bz" result))))

(test emit-zero-extend
  (let* ((ir (fab::parse-expr '(zero-extend val 16)))
         (result (emit-to-string #'fab::emit-expr ir)))
    (is (search "{16'h0," result))))

(test emit-sign-extend
  (let* ((ir (fab::parse-expr '(sign-extend val 16)))
         (result (emit-to-string #'fab::emit-expr ir)))
    (is (search "{{16{" result))))

;;; Statement parser tests

(test parse-blocking
  (let ((ir (fab::parse-stmt '(setf x 42))))
    (is (fab::ir-blocking-p ir))
    (is (eq 'x (fab::ir-ref-name (fab::ir-blocking-lhs ir))))
    (is (= 42 (fab::ir-num-value (fab::ir-blocking-rhs ir))))))

(test parse-non-blocking
  (let ((ir (fab::parse-stmt '(setf-nb x 0))))
    (is (fab::ir-non-blocking-p ir))))

(test parse-incf
  (let ((ir (fab::parse-stmt '(incf x))))
    (is (fab::ir-blocking-p ir))
    (is (fab::ir-binop-p (fab::ir-blocking-rhs ir)))
    (is (eq '+ (fab::ir-binop-op (fab::ir-blocking-rhs ir))))))

(test parse-decf
  (let ((ir (fab::parse-stmt '(decf x))))
    (is (fab::ir-blocking-p ir))
    (is (fab::ir-binop-p (fab::ir-blocking-rhs ir)))
    (is (eq '- (fab::ir-binop-op (fab::ir-blocking-rhs ir))))))

(test parse-if-stmt
  (let ((ir (fab::parse-stmt '(if cond (setf x 1)))))
    (is (fab::ir-if-p ir))
    (is (fab::ir-ref-p (fab::ir-if-cond ir)))
    (is (fab::ir-blocking-p (fab::ir-if-then ir)))))

(test parse-if-else
  (let ((ir (fab::parse-stmt '(if cond (setf x 1) (setf x 0)))))
    (is (fab::ir-if-p ir))
    (is (fab::ir-blocking-p (fab::ir-if-else ir)))))

(test parse-case-stmt
  (let ((ir (fab::parse-stmt '(case state (0 (setf x 1)) (1 (setf x 2))))))
    (is (fab::ir-case-p ir))
    (is (= 2 (length (fab::ir-case-cases ir))))))

(test parse-case-otherwise
  (let ((ir (fab::parse-stmt '(case state (0 (setf x 1)) (otherwise (setf x 9))))))
    (is (fab::ir-case-p ir))
    (is (= 1 (length (fab::ir-case-cases ir))))
    (is (fab::ir-case-default ir))))

(test parse-begin
  (let ((ir (fab::parse-stmt '(begin (setf x 1) (setf y 2)))))
    (is (fab::ir-begin-p ir))
    (is (= 2 (length (fab::ir-begin-body ir))))))

(test parse-delay
  (let ((ir (fab::parse-stmt '(delay 100))))
    (is (fab::ir-delay-p ir))
    (is (= 100 (fab::ir-num-value (fab::ir-delay-value ir))))))

(test parse-forever
  (let ((ir (fab::parse-stmt '(forever (setf x 1)))))
    (is (fab::ir-forever-p ir))))

(test parse-for
  (let ((ir (fab::parse-stmt '(for (i 0) (< i 8) (+ i 1) (setf x i)))))
    (is (fab::ir-for-p ir))))

(test parse-nil-stmt
  (is (null (fab::parse-stmt nil))))

(test parse-system-call
  (let ((ir (fab::parse-stmt '($finish))))
    (is (fab::ir-system-call-p ir))
    (is (eq 'FINISH (fab::ir-system-call-name ir)))))

(test parse-implicit-task-call
  (let* ((task-names '(my-task))
         (ir (fab::parse-stmt '(my-task arg1 arg2) task-names)))
    (is (fab::ir-task-call-p ir))
    (is (eq 'my-task (fab::ir-task-call-name ir)))
    (is (= 2 (length (fab::ir-task-call-args ir))))))

;;; Statement emitter tests

(test emit-blocking
  (let* ((ir (fab::parse-stmt '(setf x 128)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "X = 128;" result))))

(test emit-non-blocking
  (let* ((ir (fab::parse-stmt '(setf-nb x 0)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "X <= 0;" result))))

(test emit-incf
  (let* ((ir (fab::parse-stmt '(incf x)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "X" result))
    (is (search "=" result))
    (is (search "+" result))))

(test emit-delay
  (let* ((ir (fab::parse-stmt '(delay 128)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "#128;" result))))

(test emit-system-call
  (let* ((ir (fab::parse-stmt '($finish)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "$finish;" result))))

(test emit-system-call-args
  (let* ((ir (fab::parse-stmt '($dumpvars 0 tb)))
         (result (emit-to-string #'fab::emit-stmt ir)))
    (is (search "$dumpvars" result))
    (is (search "0" result))
    (is (search "TB" result))))

(test emit-nil-stmt
  (let ((result (with-output-to-string (s) (fab::emit-stmt s nil))))
    (is (string= "" result))))

;;; Port parser tests

(test parse-port-input
  (let ((ir (fab::parse-port '(clk :input))))
    (is (fab::ir-port-p ir))
    (is (eq :input (fab::ir-port-direction ir)))
    (is (null (fab::ir-port-width ir)))))

(test parse-port-output-width
  (let ((ir (fab::parse-port '(data :output 8))))
    (is (fab::ir-port-p ir))
    (is (eq :output (fab::ir-port-direction ir)))
    (is (= 8 (fab::ir-port-width ir)))))

(test parse-port-reg
  (let ((ir (fab::parse-port '(tx :output :reg))))
    (is (fab::ir-port-p ir))
    (is (eq :reg (fab::ir-port-kind ir)))))

(test parse-port-width-reg
  (let ((ir (fab::parse-port '(data :output 8 :reg))))
    (is (fab::ir-port-p ir))
    (is (= 8 (fab::ir-port-width ir)))
    (is (eq :reg (fab::ir-port-kind ir)))))

(test parse-port-inout
  (let ((ir (fab::parse-port '(usb-dp :inout))))
    (is (fab::ir-port-p ir))
    (is (eq :inout (fab::ir-port-direction ir)))))

;;; Signal parser tests

(test parse-signal-wire
  (let ((ir (fab::parse-signal '(clk :wire))))
    (is (fab::ir-signal-p ir))
    (is (eq :wire (fab::ir-signal-kind ir)))))

(test parse-signal-reg-width
  (let ((ir (fab::parse-signal '(state :reg 2))))
    (is (fab::ir-signal-p ir))
    (is (eq :reg (fab::ir-signal-kind ir)))
    (is (= 2 (fab::ir-signal-width ir)))))

(test parse-signal-init
  (let ((ir (fab::parse-signal '(counter :reg 8 :init 0))))
    (is (fab::ir-signal-p ir))
    (is (= 8 (fab::ir-signal-width ir)))
    (is (fab::ir-num-p (fab::ir-signal-init ir)))
    (is (= 0 (fab::ir-num-value (fab::ir-signal-init ir))))))

(test parse-signal-attrs
  (let ((ir (fab::parse-signal '(state :reg 2 :attrs ((fsm_encoding "binary"))))))
    (is (fab::ir-signal-p ir))
    (is (equal '((fsm_encoding "binary")) (fab::ir-signal-attrs ir)))))

;;; Signal emitter tests

(test emit-signal-wire
  (let* ((ir (fab::parse-signal '(clk :wire)))
         (result (emit-to-string #'fab::emit-signal ir)))
    (is (search "wire CLK;" result))))

(test emit-signal-reg
  (let* ((ir (fab::parse-signal '(state :reg 2)))
         (result (emit-to-string #'fab::emit-signal ir)))
    (is (search "reg" result))
    (is (search "[1:0]" result))
    (is (search "STATE" result))))

(test emit-signal-attrs
  (let* ((ir (fab::parse-signal '(state :reg 2 :attrs ((fsm_encoding "binary")))))
         (result (emit-to-string #'fab::emit-signal ir)))
    (is (search "fsm_encoding" result))
    (is (search "binary" result))))

;;; Port emitter tests

(test emit-port-input
  (let* ((ir (fab::parse-port '(clk :input)))
         (result (emit-to-string #'fab::emit-port ir)))
    (is (search "input CLK;" result))))

(test emit-port-output-width
  (let* ((ir (fab::parse-port '(data :output 8)))
         (result (emit-to-string #'fab::emit-port ir)))
    (is (search "output" result))
    (is (search "[7:0]" result))
    (is (search "DATA" result))))

(test emit-port-reg
  (let* ((ir (fab::parse-port '(tx :output :reg)))
         (result (emit-to-string #'fab::emit-port ir)))
    (is (search "output reg" result))))

;;; Instance parser tests

(test parse-instance
  (let ((ir (fab::parse-instance '(instance my-mod (u0) ((width 8)) ((clk clk) (data x))))))
    (is (fab::ir-instance-p ir))
    (is (eq 'my-mod (fab::ir-instance-module ir)))
    (is (eq 'u0 (fab::ir-instance-name ir)))
    (is (= 1 (length (fab::ir-instance-params ir))))
    (is (= 2 (length (fab::ir-instance-ports ir))))))

(test parse-instance-no-params
  (let ((ir (fab::parse-instance '(instance my-mod (u0) () ((clk clk))))))
    (is (fab::ir-instance-p ir))
    (is (null (fab::ir-instance-params ir)))))

;;; Instance emitter tests

(test emit-instance
  (let* ((ir (fab::parse-instance '(instance my-mod (u0) () ((clk clk) (data x)))))
         (result (emit-to-string #'fab::emit-instance ir)))
    (is (search "MY_MOD" result))
    (is (search "U0" result))
    (is (search ".CLK(CLK)" result))
    (is (search ".DATA(X)" result))))

(test emit-instance-with-params
  (let* ((ir (fab::parse-instance '(instance my-mod (u0) ((WIDTH 8)) ((clk clk)))))
         (result (emit-to-string #'fab::emit-instance ir)))
    (is (search "#" result))
    (is (search ".WIDTH(8)" result))))

(test emit-instance-string-module
  (let* ((ir (fab::parse-instance '(instance "rPLL" (u_pll) () ((clk clk)))))
         (result (emit-to-string #'fab::emit-instance ir)))
    (is (search "rPLL" result))))

;;; Always parser tests

(test parse-always
  (let ((ir (fab::parse-always '(always (posedge clk) (setf x 0)))))
    (is (fab::ir-always-p ir))
    (is (listp (fab::ir-always-sensitivity ir)))
    (is (fab::ir-begin-p (fab::ir-always-body ir)))))

(test parse-always-comb
  (let ((ir (fab::parse-body-item '(always-comb (setf x a)))))
    (is (fab::ir-always-comb-p ir))))

;;; Sensitivity parser tests

(test parse-sensitivity-single
  (let ((ir (fab::parse-sensitivity '(posedge clk))))
    (is (listp ir))
    (is (= 1 (length ir)))
    (is (eq 'posedge (first (first ir))))
    (is (eq 'clk (second (first ir))))))

(test parse-sensitivity-async-reset
  (let ((ir (fab::parse-sensitivity '(posedge clk (negedge rstn)))))
    (is (= 2 (length ir)))
    (is (eq 'negedge (first (second ir))))))

(test parse-sensitivity-star
  (is (eq :* (fab::parse-sensitivity '*))))

;;; Sensitivity emitter tests

(test emit-sensitivity-single
  (let ((result (fab::emit-sensitivity '((posedge clk)))))
    (is (string= "posedge CLK" result))))

(test emit-sensitivity-async
  (let ((result (fab::emit-sensitivity '((posedge clk) (negedge rstn)))))
    (is (search "posedge CLK" result))
    (is (search "or" result))
    (is (search "negedge RSTN" result))))

(test emit-sensitivity-star
  (is (string= "*" (fab::emit-sensitivity :*))))

;;; Param/localparam parser tests

(test parse-param
  (let ((ir (fab::parse-param '(baud-rate 115200))))
    (is (fab::ir-param-p ir))
    (is (= 115200 (fab::ir-num-value (fab::ir-param-value ir))))))

(test parse-param-with-width
  (let ((ir (fab::parse-param '(data 0 :width 8))))
    (is (fab::ir-param-p ir))
    (is (fab::ir-num-p (fab::ir-param-width ir)))
    (is (= 8 (fab::ir-num-value (fab::ir-param-width ir))))))

(test parse-localparam
  (let ((ir (fab::parse-localparam '(state-idle 0))))
    (is (fab::ir-localparam-p ir))
    (is (= 0 (fab::ir-num-value (fab::ir-localparam-value ir))))))

;;; Param/localparam emitter tests

(test emit-param
  (let* ((ir (fab::parse-param '(baud-rate 115200)))
         (result (emit-to-string #'fab::emit-param ir)))
    (is (search "parameter" result))
    (is (search "BAUD_RATE" result))
    (is (search "115200" result))))

(test emit-localparam
  (let* ((ir (fab::parse-localparam '(state-idle 0)))
         (result (emit-to-string #'fab::emit-localparam ir)))
    (is (search "localparam" result))
    (is (search "STATE_IDLE" result))))

(test emit-param-with-width
  (let* ((ir (fab::parse-param '(data 0 :width 8)))
         (result (emit-to-string #'fab::emit-param ir)))
    (is (search "[7:0]" result))))

;;; Defparam parser tests

(test parse-defparam-dot
  (let ((ir (fab::parse-defparam '(defparam my-inst.my-param 42))))
    (is (fab::ir-defparam-p ir))
    (is (string= "MY-INST" (fab::ir-defparam-inst-name ir)))
    (is (string= "MY-PARAM" (fab::ir-defparam-param-name ir)))))

(test parse-defparam-3args
  (let ((ir (fab::parse-defparam '(defparam my-inst my-param 42))))
    (is (fab::ir-defparam-p ir))
    (is (string= "MY-INST" (fab::ir-defparam-inst-name ir)))
    (is (string= "MY-PARAM" (fab::ir-defparam-param-name ir)))))

;;; Defparam emitter tests

(test emit-defparam
  (let* ((ir (fab::parse-defparam '(defparam my-inst.my-param 42)))
         (result (emit-to-string #'fab::emit-defparam ir)))
    (is (search "defparam" result))
    (is (search "MY_INST.MY_PARAM" result))
    (is (search "42" result))))

;;; Generate-if parser tests

(test parse-generate-if
  (let ((ir (fab::parse-generate-if '(generate-if ena ((instance my-mod (u0) () ((clk clk))))))))
    (is (fab::ir-generate-if-p ir))
    (is (= 1 (length (fab::ir-generate-if-then ir))))))

(test parse-generate-if-else
  (let ((ir (fab::parse-generate-if '(generate-if ena
                                      ((instance mod-a (ua) () ((clk clk))))
                                      ((instance mod-b (ub) () ((clk clk))))))))
    (is (fab::ir-generate-if-p ir))
    (is (= 1 (length (fab::ir-generate-if-then ir))))
    (is (= 1 (length (fab::ir-generate-if-else ir))))))

;;; Generate-if emitter tests

(test emit-generate-if
  (let* ((ir (fab::parse-generate-if '(generate-if ena ((instance my-mod (u0) () ((clk clk)))))))
         (result (emit-to-string #'fab::emit-generate-if ir)))
    (is (search "generate" result))
    (is (search "if (ENA)" result))
    (is (search "begin" result))
    (is (search "MY_MOD" result))
    (is (search "endgenerate" result))))

;;; Module parser tests

(test parse-module-minimal
  (let ((ir (fab::parse-module '(module my-mod :ports ((clk :input)) :body ()))))
    (is (fab::ir-module-p ir))
    (is (eq 'my-mod (fab::ir-module-name ir)))
    (is (= 1 (length (remove-if-not #'fab::ir-port-p (fab::ir-module-items ir)))))))

(test parse-module-with-signals
  (let ((ir (fab::parse-module '(module my-mod
                                  :ports ((clk :input))
                                  :signals ((x :reg 8))
                                  :body ()))))
    (is (= 1 (length (remove-if-not #'fab::ir-signal-p (fab::ir-module-items ir)))))))

(test parse-module-with-assigns
  (let ((ir (fab::parse-module '(module my-mod
                                  :ports ((clk :input) (led :output))
                                  :assigns ((led clk))
                                  :body ()))))
    (is (= 1 (length (remove-if-not #'fab::ir-cont-assign-p (fab::ir-module-items ir)))))))

;;; Task parser tests

(test parse-task
  (let ((ir (fab::parse-task '(my-task ((x :reg 8)) (setf x 0)))))
    (is (fab::ir-task-p ir))
    (is (eq 'my-task (fab::ir-task-name ir)))
    (is (= 1 (length (fab::ir-task-params ir))))
    (is (= 1 (length (fab::ir-task-body ir))))))

;;; Function parser tests

(test parse-function
  (let ((ir (fab::parse-function '(my-func ((x :reg 8)) :returns (:reg 8) :body ((setf my-func x))))))
    (is (fab::ir-function-p ir))
    (is (eq 'my-func (fab::ir-function-name ir)))
    (is (= 1 (length (fab::ir-function-params ir))))))

;;; Board parser tests

(test parse-board
  (let ((ir (fab::parse-board '(board my-board
                                 :device "GW1NR-LV9QN88PC6/I5"
                                 :family "GW1N-9C"
                                 :clock 52
                                 :pins ((led 10) (btn 3))))))
    (is (fab::ir-board-p ir))
    (is (string= "GW1NR-LV9QN88PC6/I5" (ir-board-device ir)))
    (is (string= "GW1N-9C" (ir-board-family ir)))
    (is (= 52 (ir-board-clock ir)))
    (is (= 2 (length (ir-board-pins ir))))))

;;; Width range tests

(test width-range-nil
  (is (null (fab::width-range nil))))

(test width-range-1
  (is (null (fab::width-range 1))))

(test width-range-8
  (is (string= "[7:0] " (fab::width-range 8))))

;;; Verilog identifier tests

(test verilog-ident-simple
  (is (string= "MY_SIGNAL" (fab::verilog-ident 'my-signal))))

(test verilog-ident-underscore
  (is (string= "FOO_BAR" (fab::verilog-ident 'foo-bar))))

;;; Run all tests

(defun run-tests ()
  (let ((results (fiveam:run 'fab-suite)))
    (fiveam:explain! results)
    (fiveam:results-status results)))
