;;; USB HID Keyboard - batch loader
;;; Loads all modules and generates Verilog into build/
;;;
;;; Usage (from CL REPL):
;;;   (asdf:load-system "fab")
;;;   (load "examples/03-usb-keyboard/load.lisp")
;;;
;;; Or from shell:
;;;   sbcl --eval '(asdf:load-system "fab")' --load examples/03-usb-keyboard/load.lisp --quit

(in-package :fab)

;; Set output directory for generated Verilog
(setf *output-dir* (merge-pathnames "build/" (asdf:system-source-directory "fab")))

;; Board definition (must be loaded first — registers in *boards*)
(load #p"boards/tangnano9k/tangnano9k.lisp")

;; USB keyboard modules (order doesn't matter — they're independent)
(load #p"examples/03-usb-keyboard/pll-48mhz.lisp")
(load #p"examples/03-usb-keyboard/usbfs-debug-uart-tx.lisp")
(load #p"examples/03-usb-keyboard/usbfs-debug-monitor.lisp")
(load #p"examples/03-usb-keyboard/usbfs-bitlevel.lisp")
(load #p"examples/03-usb-keyboard/usbfs-packet-tx.lisp")
(load #p"examples/03-usb-keyboard/usbfs-packet-rx.lisp")
(load #p"examples/03-usb-keyboard/usbfs-transaction.lisp")
(load #p"examples/03-usb-keyboard/usbfs-core-top.lisp")
(load #p"examples/03-usb-keyboard/usb-keyboard-scanner.lisp")
(load #p"examples/03-usb-keyboard/usb-keyboard-top.lisp")
(load #p"examples/03-usb-keyboard/usb-keyboard.lisp")

(format t "~%All USB keyboard modules generated into ~a~%" *output-dir*)
