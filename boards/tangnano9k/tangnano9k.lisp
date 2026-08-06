(in-package :fab)

;;; Board definition: Sipeed Tang Nano 9K
;;; https://www.sipeed.com/hardware/tang-nano-9k.html

(fab
 (board tangnano9k
   :device "GW1NR-LV9QN88PC6/I5"
   :family "GW1N-9C"
   :clock 52
   :pins ((uart-tx 17)
          (uart-rx 18)
          (led 10)
          (led2 11)
          (led3 13)
          (led4 14)
          (led5 15)
          (btn1 3)
          (btn2 4)
          (btn 3)
           (usb-dp-pull 27)
           (usb-dp 25)
           (usb-dn 26))))
