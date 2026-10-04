(defpackage #:git-agent-workflow.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:export #:apply-ref-transaction
           #:select-source-ref
           #:restore-source-selection
           #:initialize-source-and-selector
           #:remove-initial-source-and-selector
           #:rename-selected-source
           #:delete-selector
           #:delete-symbolic-ref
           #:selector-change
           #:selector-change-p
           #:protocol-refs
           #:inspect-ref
           #:ref-dangling-p
           #:current-ref
           #:current-ref-error
           #:current-ref-error-reason
           #:ref-state
           #:ref-state-name
           #:ref-state-exists-p
           #:ref-state-symbolic-p
           #:ref-state-symbolic-target
           #:ref-state-object-id))
