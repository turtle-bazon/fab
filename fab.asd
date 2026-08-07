(asdf:defsystem "fab"
  :description "(fab): a Common Lisp fabric for building hardware via a language-neutral IR with per-target HDL emitters."
  :long-description "(fab) is a Common Lisp toolchain that describes digital hardware (modules, ports, signals, registers, memories) in a neutral IR and emits Verilog (later VHDL). The IR is the golden description; emitted HDL is only a projection."
  :author "turtle"
  :license "GPL-3.0-or-later"
  :version "0.0.1.0"
  :depends-on (:iterate
               :metabang-bind
               :clingon)
  :serial t
  :components ((:module "src"
                :serial t
                :components
                ((:file "packages")
                 (:file "ir")
                 (:file "emit-verilog")
                 (:file "fab-macro")
                 (:file "main"))))
  :build-operation "program-op"
  :build-pathname "build/fab"
  :entry-point "fab:main")