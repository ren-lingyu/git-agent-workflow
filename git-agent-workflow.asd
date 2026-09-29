(asdf:defsystem "git-agent-workflow"
  :version "0.0.0"
  :description "Git Agent Workflow (GAW)"
  :depends-on ("uiop")

  :components ((:module "src"
                :pathname "src/"
                :components ((:file "package")
                             (:module "git"
                              :pathname "git/"
                              :depends-on ("package")
                              :components ((:file "package")
                                           (:file "git.lib"
                                            :depends-on ("package"))))
                             (:module "refs"
                              :pathname "refs/"
                              :depends-on ("package"
                                           "git")
                              :components ((:file "package")
                                           (:file "refs.lib"
                                            :depends-on ("package"))
                                           (:file "refs.api"
                                            :depends-on ("refs.lib"))
                                           (:file "current.lib"
                                            :depends-on ("refs.lib"))
                                           (:file "current.api"
                                            :depends-on ("refs.api"
                                                         "current.lib"))))
                             (:module "cli"
                              :pathname "cli/"
                              :depends-on ("package")
                              :components ((:file "package")
                                           (:file "cli.api"
                                            :depends-on ("package")))))))

  :build-operation program-op
  :build-pathname "git-gaw"
  :entry-point "git-agent-workflow.cli:main"

  :in-order-to ((asdf:test-op (asdf:test-op "git-agent-workflow/tests"))))

(asdf:defsystem "git-agent-workflow/tests"
  :depends-on ("git-agent-workflow")

  :components ((:module "tests"
                :pathname "tests/"
                :components ((:file "package")
                             (:file "support"
                              :depends-on ("package"))
                             (:module "git"
                              :pathname "git/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "git"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("git"))))
                             (:module "refs"
                              :pathname "refs/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "refs"
                                            :depends-on ("package"))
                                           (:file "current"
                                            :depends-on ("refs"))
                                           (:file "tests"
                                            :depends-on ("refs"
                                                         "current"))))
                             (:file "tests"
                              :depends-on ("package"
                                           "git"
                                           "refs")))))

  :perform (asdf:test-op (operation component)
                         (declare (ignore operation
                                          component))
                         (uiop:symbol-call :git-agent-workflow/tests
                                           :run-tests)))
