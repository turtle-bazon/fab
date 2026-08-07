;;; USB HID Keyboard - batch loader (fallback)
;;; Loads all modules and generates Verilog into build/
;;;
;;; Prefer loading just usb-keyboard.lisp — :depends handles the rest.
;;; This file exists as a fallback for batch processing.

(in-package :fab)

;; Set output directory for generated Verilog
(setf *output-dir* (merge-pathnames "build/" (asdf:system-source-directory "fab")))

;; Board definition
(load #p"boards/tangnano9k/tangnano9k.lisp")

;; USB keyboard modules
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
