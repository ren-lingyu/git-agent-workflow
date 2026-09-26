(asdf:defsystem "git-agent-workflow"
  :version "0.0.0"
  :description "Git Agent Workflow (GAW)"
  :depends-on ("uiop")

  :components ((:module "src"
                :pathname "src/"
                :components ((:file "package")
                             (:file "cli"
                              :depends-on ("package")))))

  :build-operation program-op
  :build-pathname "git-gaw"
  :entry-point "git-agent-workflow.cli:main"
  :in-order-to ((asdf:test-op (asdf:test-op "git-agent-workflow/tests"))))

(asdf:defsystem "git-agent-workflow/tests"
  :depends-on ("git-agent-workflow")
  :components ((:module "tests"
                :components ((:file "package")
                             (:file "tests"
                              :depends-on ("package"))))))
