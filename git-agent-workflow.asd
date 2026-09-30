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
                             (:module "workspace"
                              :pathname "workspace/"
                              :depends-on ("package"
                                           "git")
                              :components ((:file "package")
                                           (:file "workspace.core"
                                            :depends-on ("package"))
                                           (:file "workspace.runtime"
                                            :depends-on ("workspace.core"))
                                           (:file "workspace.api"
                                            :depends-on ("workspace.runtime"))))
                             (:module "commit"
                              :pathname "commit/"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "config"
                                           "workspace")
                              :components ((:file "package")
                                           (:file "commit.core"
                                            :depends-on ("package"))
                                           (:file "commit.runtime"
                                            :depends-on ("commit.core"))
                                           (:file "commit.api"
                                            :depends-on ("commit.runtime"))))
                             (:module "show"
                              :pathname "show/"
                              :depends-on ("package"
                                           "git")
                              :components ((:file "package")
                                           (:file "show.core"
                                            :depends-on ("package"))
                                           (:file "show.runtime"
                                            :depends-on ("show.core"))
                                           (:file "show.api"
                                            :depends-on ("show.runtime"))))
                             (:module "check"
                              :pathname "check/"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "config"
                                           "workspace")
                              :components ((:file "package")
                                           (:file "check.core"
                                            :depends-on ("package"))
                                           (:file "check.runtime"
                                            :depends-on ("check.core"))
                                           (:file "check.api"
                                            :depends-on ("check.runtime"))))
                             (:module "help"
                              :pathname "help/"
                              :depends-on ("package")
                              :components ((:file "package")
                                           (:module "text"
                                            :pathname "text/"
                                            :components
                                            ((:static-file "overview.txt")
                                             (:static-file "commit.txt")
                                             (:static-file "show.txt")
                                             (:static-file "check.txt")))
                                           (:file "help.core"
                                            :depends-on ("package" "text"))
                                           (:file "help.api"
                                            :depends-on ("help.core"))))
                             (:module "cli"
                              :pathname "cli/"
                              :depends-on ("package"
                                           "commit"
                                           "show")
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
                             (:module "commit"
                              :pathname "commit/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "commit"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("commit"))))
                             (:module "workspace"
                              :pathname "workspace/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "workspace"
                                            :depends-on ("package"))))
                             (:module "show"
                              :pathname "show/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "show"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("show"))))
                             (:module "check"
                              :pathname "check/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "check"
                                            :depends-on ("package"))))
                             (:module "help"
                              :pathname "help/"
                              :depends-on ("package")
                              :components ((:file "package")
                                           (:file "help"
                                            :depends-on ("package"))))
                             (:module "cli"
                              :pathname "cli/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "cli"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("cli"))))
                             (:file "tests"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "config"
                                           "commit"
                                           "workspace"
                                           "show"
                                           "check"
                                           "help"
                                           "cli")))))

  :perform (asdf:test-op (operation component)
                         (declare (ignore operation
                                          component))
                         (uiop:symbol-call :git-agent-workflow/tests
                                           :run-tests)))
