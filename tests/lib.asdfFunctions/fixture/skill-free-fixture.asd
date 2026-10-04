(asdf:defsystem "skill-free-fixture"
  :components ((:module "src"
                :pathname "src/"
                :components ((:file "main"))))
  :build-operation program-op
  :build-pathname "fixture-program"
  :entry-point "cl-user::main")
