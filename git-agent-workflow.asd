(asdf:defsystem "git-agent-workflow"
  :version "0.0.0"
  :description "Git Agent Workflow (GAW)"
  :depends-on ("uiop"
               "babel")

  :components ((:module "src"
                :pathname "src/"
                :components ((:file "package")
                             (:module "git"
                              :pathname "git/"
                              :depends-on ("package")
                              :components ((:file "package")
                                           (:file "git.core"
                                            :depends-on ("package"))
                                           (:file "git.runtime"
                                            :depends-on ("git.core"))))
                             (:module "refs"
                              :pathname "refs/"
                              :depends-on ("package"
                                           "git")
                              :components ((:file "package")
                                           (:file "refs.core"
                                            :depends-on ("package"))
                                           (:file "refs.runtime"
                                            :depends-on ("refs.core"))
                                           (:file "refs.api"
                                            :depends-on ("refs.runtime"))
                                           (:file "current.core"
                                            :depends-on ("refs.core"))
                                           (:file "current.runtime"
                                            :depends-on ("refs.runtime"
                                                         "current.core"))
                                           (:file "current.api"
                                            :depends-on ("refs.api"
                                                         "current.runtime"))))
                             (:module "config"
                              :pathname "config/"
                              :depends-on ("package"
                                           "git"
                                           "refs")
                              :components ((:file "package")
                                           (:file "config.core"
                                            :depends-on ("package"))
                                           (:file "config.runtime"
                                            :depends-on ("config.core"))
                                           (:file "config.api"
                                            :depends-on ("config.runtime"))))
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
                             (:module "config"
                              :pathname "config/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "config"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("config"))))
                             (:file "tests"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "config")))))

  :perform (asdf:test-op (operation component)
                         (declare (ignore operation
                                          component))
                         (uiop:symbol-call :git-agent-workflow/tests
                                           :run-tests)))
