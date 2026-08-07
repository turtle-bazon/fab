;;; USB HID Keyboard top-level for Tang Nano 9K
;;; Instantiates PLL, keyboard scanner, USB keyboard core, and LED

(in-package :fab)

(fab
 (module usb-keyboard-tangnano9k
   :depends (pll-48mhz usb-keyboard-scanner usb-keyboard-top)
   :board :tangnano9k
   :ports ((clk-27mhz :input)
           (btn :input)
           (led :output)
           (usb-dp-pull :output)
           (usb-dp :inout)
           (usb-dn :inout))
   :signals ((clk-48mhz :wire)
             (pll-locked :wire)
             (usb-rstn :wire)
             (rstn :wire)
             (key-value :wire 16)
             (key-request :wire))
   :assigns ((rstn (logand btn pll-locked))
             (led usb-rstn))
   :body
   ((instance pll-48mhz (u-pll)
              nil
              ((clk-27mhz clk-27mhz)
               (clk-48mhz clk-48mhz)
               (locked pll-locked)))
    (instance usb-keyboard-scanner (u-scanner)
              nil
              ((clk clk-48mhz)
               (rst rstn)
               (key-value key-value)
               (key-request key-request)))
    (instance usb-keyboard-top (u-keyboard)
              nil
              ((rstn rstn)
               (clk clk-48mhz)
               (usb-dp-pull usb-dp-pull)
               (usb-dp usb-dp)
               (usb-dn usb-dn)
               (usb-rstn usb-rstn)
               (key-value key-value)
               (key-request key-request))))))
