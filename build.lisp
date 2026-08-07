(ql:quickload "fab")
(ensure-directories-exist #p"build/fab")
(asdf:make "fab")
