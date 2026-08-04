(in-package :fab)

;;; Expressions

(defstruct (ir-num (:constructor ir-num (value))) value)
(defstruct (ir-str (:constructor ir-str (value))) value)
(defstruct (ir-ref (:constructor ir-ref (name))) name)
(defstruct (ir-binop (:constructor ir-binop (op left right))) op left right)
(defstruct (ir-unop (:constructor ir-unop (op arg))) op arg)
(defstruct (ir-bitselect (:constructor ir-bitselect (signal index))) signal index)
(defstruct (ir-partselect (:constructor ir-partselect (signal hi lo))) signal hi lo)

;;; Statements

(defstruct (ir-blocking (:constructor ir-blocking (lhs rhs))) lhs rhs)
(defstruct (ir-non-blocking (:constructor ir-non-blocking (lhs rhs))) lhs rhs)
(defstruct (ir-if (:constructor ir-if (cond then else))) cond then else)
(defstruct (ir-case (:constructor ir-case (key cases default))) key cases default)
(defstruct (ir-begin (:constructor ir-begin (body))) body)

;;; Module items

(defstruct (ir-port (:constructor ir-port (name direction width))) name direction width)
(defstruct (ir-signal (:constructor ir-signal (name kind width attrs))) name kind width attrs)
(defstruct (ir-param (:constructor ir-param (name value))) name value)
(defstruct (ir-localparam (:constructor ir-localparam (name value))) name value)
(defstruct (ir-always (:constructor ir-always (sensitivity body))) sensitivity body)
(defstruct (ir-cont-assign (:constructor ir-cont-assign (lhs rhs))) lhs rhs)

;;; Testbench constructs

(defstruct (ir-delay (:constructor ir-delay (value))) value)
(defstruct (ir-system-call (:constructor ir-system-call (name args))) name args)
(defstruct (ir-initial (:constructor ir-initial (body))) body)
(defstruct (ir-always-comb (:constructor ir-always-comb (body))) body)
(defstruct (ir-forever (:constructor ir-forever (body))) body)
(defstruct (ir-instance (:constructor ir-instance (module name params ports))) module name params ports)

;;; Top level

(defstruct (ir-module (:constructor ir-module (name items))) name items)
(defstruct (ir-testbench (:constructor ir-testbench (name items))) name items)
