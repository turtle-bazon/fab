(in-package :fab)

;;; Expressions

(defstruct (ir-num (:constructor ir-num (value))) value)
(defstruct (ir-str (:constructor ir-str (value))) value)
(defstruct (ir-ref (:constructor ir-ref (name))) name)
(defstruct (ir-binop (:constructor ir-binop (op left right))) op left right)
(defstruct (ir-unop (:constructor ir-unop (op arg))) op arg)
(defstruct (ir-bitselect (:constructor ir-bitselect (signal index))) signal index)
(defstruct (ir-partselect (:constructor ir-partselect (signal hi lo))) signal hi lo)
(defstruct (ir-concat (:constructor ir-concat (items))) items)
(defstruct (ir-funcall (:constructor ir-funcall (name args))) name args)
(defstruct (ir-if-expr (:constructor ir-if-expr (cond then else))) cond then else)
(defstruct (ir-high-z (:constructor ir-high-z (width))) width)
(defstruct (ir-zero-extend (:constructor ir-zero-extend (value target-width))) value target-width)
(defstruct (ir-sign-extend (:constructor ir-sign-extend (value target-width))) value target-width)

;;; Statements

(defstruct (ir-blocking (:constructor ir-blocking (lhs rhs))) lhs rhs)
(defstruct (ir-non-blocking (:constructor ir-non-blocking (lhs rhs))) lhs rhs)
(defstruct (ir-if (:constructor ir-if (cond then else))) cond then else)
(defstruct (ir-case (:constructor ir-case (key cases default))) key cases default)
(defstruct (ir-begin (:constructor ir-begin (body))) body)
(defstruct (ir-task-call (:constructor ir-task-call (name args))) name args)
(defstruct (ir-for (:constructor ir-for (var init cond step body))) var init cond step body)

;;; Module items

(defstruct (ir-port (:constructor ir-port (name direction width kind))) name direction width kind)
(defstruct (ir-signal (:constructor ir-signal (name kind width attrs init))) name kind width attrs init)
(defstruct (ir-param (:constructor ir-param (name value)) (:constructor ir-param-with-width (name width value))) name value width)
(defstruct (ir-localparam (:constructor ir-localparam (name value)) (:constructor ir-localparam-with-width (name width value))) name value width)
(defstruct (ir-always (:constructor ir-always (sensitivity body))) sensitivity body)
(defstruct (ir-cont-assign (:constructor ir-cont-assign (lhs rhs))) lhs rhs)
(defstruct (ir-task (:constructor ir-task (name params body))) name params body)
(defstruct (ir-function (:constructor ir-function (name params ret-width body))) name params ret-width body)

;;; Testbench constructs

(defstruct (ir-delay (:constructor ir-delay (value))) value)
(defstruct (ir-system-call (:constructor ir-system-call (name args))) name args)
(defstruct (ir-initial (:constructor ir-initial (body))) body)
(defstruct (ir-always-comb (:constructor ir-always-comb (body))) body)
(defstruct (ir-forever (:constructor ir-forever (body))) body)
(defstruct (ir-instance (:constructor ir-instance (module name params ports))) module name params ports)

;;; Top level

(defstruct (ir-defparam (:constructor ir-defparam (inst-name param-name value))) inst-name param-name value)
(defstruct (ir-generate-if (:constructor ir-generate-if (cond then else))) cond then else)
(defstruct (ir-board (:constructor ir-board (name device family clock pins))) name device family clock pins)
(defstruct (ir-module (:constructor ir-module (name board items tasks functions))) name board items tasks functions)
(defstruct (ir-testbench (:constructor ir-testbench (name items))) name items)
