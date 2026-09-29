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
           #:current-ref
           #:current-ref-error
           #:current-ref-error-reason
           #:ref-state
           #:ref-state-name
           #:ref-state-exists-p
           #:ref-state-symbolic-p
           #:ref-state-symbolic-target))
