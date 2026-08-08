(asdf:defsystem "fab-test"
  :description "Tests for (fab)"
  :depends-on (:fiveam :fab)
  :serial t
  :components ((:module "test"
                :serial t
                :components ((:file "fab-test")))))
