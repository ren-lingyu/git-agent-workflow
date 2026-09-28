(defpackage #:git-agent-workflow
  (:use #:cl))

(defpackage #:git-agent-workflow.git
  (:use #:cl)
  (:export #:run-git
           #:git-invocation
           #:git-invocation-command
           #:git-invocation-arguments
           #:git-invocation-directory
           #:git-invocation-stdout
           #:git-invocation-stderr
           #:git-invocation-exit-status))

(defpackage #:git-agent-workflow.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:export #:make-ref
           #:inspect-ref
           #:ref-dangling-p
           #:register-ref
           #:unregister-ref
           #:ref-state
           #:ref-state-name
           #:ref-state-exists-p
           #:ref-state-symbolic-p
           #:ref-state-symbolic-target))

(defpackage #:git-agent-workflow.cli
  (:use #:cl)
  (:export #:main))
