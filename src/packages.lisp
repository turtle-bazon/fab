(in-package :cl-user)

(defpackage :fab
  (:use :cl
        :iterate
        :metabang-bind)
  (:nicknames :fab)
  (:export #:fab
           #:fab-impl
           #:*output-dir*
           #:*board-dirs*
           #:*board-targets*
           #:main))
