(defpackage #:git-agent-workflow.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:export #:make-ref
           #:apply-ref-transaction
           #:registration-refs
           #:protocol-refs
           #:select-ref
           #:restore-selection
           #:initialize-ref-graph
           #:remove-initial-ref-graph
           #:rename-ref-registration
           #:remove-ref-registration
           #:restore-ref-registration
           #:registration-removal
           #:registration-removal-p
           #:selection-change
           #:selection-change-p
           #:registered-ref-p
           #:registration-error
           #:registration-error-reason
           #:registration-error-ref
           #:registration-error-target
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
           #:ref-state-symbolic-target
           #:ref-state-object-id))
