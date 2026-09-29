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
