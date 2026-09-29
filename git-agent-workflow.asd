(asdf:defsystem "git-agent-workflow"
  :version "0.0.0"
  :description "Git Agent Workflow (GAW)"
  :depends-on ("uiop")

  :components ((:module "src"
                :pathname "src/"
                :components ((:file "package")
                             (:file "git"
                              :depends-on ("package"))
                             (:file "refs"
                              :depends-on ("package"
                                           "git"))
                             (:file "refs.current"
                              :depends-on ("package"
                                           "refs"))
                             (:file "cli"
                              :depends-on ("package")))))

  :build-operation program-op
  :build-pathname "git-gaw"
  :entry-point "git-agent-workflow.cli:main"

  :in-order-to ((asdf:test-op (asdf:test-op "git-agent-workflow/tests"))))

(asdf:defsystem "git-agent-workflow/tests"
  :depends-on ("git-agent-workflow")

  :components ((:module "tests"
                :pathname "tests/"
                :components ((:file "package")
                             (:file "package.support"
                              :depends-on ("package"))
                             (:file "git"
                              :depends-on ("package"
                                           "package.support"))
                             (:file "git.tests"
                              :depends-on ("package"
                                           "git"))
                             (:file "refs"
                              :depends-on ("package"
                                           "package.support"))
                             (:file "refs.current"
                              :depends-on ("package"
                                           "package.support"
                                           "refs"))
                             (:file "refs.tests"
                              :depends-on ("package"
                                           "refs"
                                           "refs.current"))
                             (:file "tests"
                              :depends-on ("package"
                                           "git.tests"
                                           "refs.tests")))))

  :perform (asdf:test-op (operation component)
                         (declare (ignore operation
                                          component))
                         (uiop:symbol-call :git-agent-workflow/tests
                                           :run-tests)))
