(asdf:defsystem "git-agent-workflow"
  :version "0.1.0"
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
                                           (:file "git.external"
                                            :depends-on ("package"))
                                           (:file "git.core"
                                            :depends-on ("package"))
                                           (:file "git.runtime"
                                            :depends-on ("git.core"))
                                           (:file "git.api"
                                            :depends-on ("git.external"
                                                         "git.runtime"))))
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
                             (:module "state"
                              :pathname "state/"
                              :depends-on ("package"
                                           "git"
                                           "config"
                                           "workspace")
                              :components ((:file "package")
                                           (:file "state.core"
                                            :depends-on ("package"))
                                           (:file "state.runtime"
                                            :depends-on ("state.core"))
                                           (:file "state.api"
                                            :depends-on ("state.runtime"))))
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
                                           "workspace"
                                           "state"
                                           "hook")
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
                                             (:static-file "check.txt")
                                             (:static-file "deploy.txt")
                                             (:static-file "init.txt")
                                             (:static-file "branch.txt")))
                                           (:file "help.core"
                                            :depends-on ("package" "text"))
                                           (:file "help.api"
                                            :depends-on ("help.core"))))
                             (:module "hook"
                              :pathname "hook/"
                              :depends-on ("package"
                                           "git"
                                           "refs")
                              :components ((:file "package")
                                           (:file "hook.core"
                                            :depends-on ("package"))
                                           (:file "hook.runtime"
                                            :depends-on ("hook.core"))
                                           (:file "hook.api"
                                            :depends-on ("hook.runtime"))))
                             (:module "deploy"
                              :pathname "deploy/"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "state"
                                           "hook"
                                           "check")
                              :components ((:file "package")
                                           (:file "deploy.core"
                                            :depends-on ("package"))
                                           (:file "deploy.runtime"
                                            :depends-on ("deploy.core"))
                                           (:file "deploy.api"
                                            :depends-on ("deploy.runtime"))))
                             (:module "init"
                              :pathname "init/"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "state"
                                           "hook"
                                           "deploy")
                              :components ((:file "package")
                                           (:file "init.core"
                                            :depends-on ("package"))
                                           (:file "init.runtime"
                                            :depends-on ("init.core"))
                                           (:file "init.api"
                                            :depends-on ("init.runtime"))))
                             (:module "branch"
                              :pathname "branch/"
                              :depends-on ("package"
                                           "git"
                                           "refs"
                                           "workspace"
                                           "state")
                              :components ((:file "package")
                                           (:file "branch.core"
                                            :depends-on ("package"))
                                           (:file "branch.runtime"
                                            :depends-on ("branch.core"))
                                           (:file "branch.api"
                                            :depends-on ("branch.runtime"))))
                             (:module "cli"
                              :pathname "cli/"
                              :depends-on ("package"
                                           "commit"
                                           "show"
                                           "check"
                                           "deploy"
                                           "init"
                                           "branch"
                                           "help"
                                           "hook")
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
                             (:module "state"
                              :pathname "state/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "state"
                                            :depends-on ("package"))))
                             (:module "deploy"
                              :pathname "deploy/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "deploy"
                                            :depends-on ("package"))))
                             (:module "init"
                              :pathname "init/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "init"
                                            :depends-on ("package"))))
                             (:module "branch"
                              :pathname "branch/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "branch"
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
                             (:module "hook"
                              :pathname "hook/"
                              :depends-on ("package"
                                           "support")
                              :components ((:file "package")
                                           (:file "hook"
                                            :depends-on ("package"))
                                           (:file "integration"
                                            :depends-on ("package"))
                                           (:file "tests"
                                            :depends-on ("hook"
                                                         "integration"))))
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
                                           "state"
                                           "deploy"
                                           "init"
                                           "branch"
                                           "show"
                                           "check"
                                           "help"
                                           "hook"
                                           "cli")))))

  :perform (asdf:test-op (operation component)
                         (declare (ignore operation
                                          component))
                         (uiop:symbol-call :git-agent-workflow/tests
                                           :run-tests)))
