(defpackage #:git-agent-workflow.hook
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:inspect-ref
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target
                #:ref-state-object-id)
  (:import-from #:git-agent-workflow.state
                #:inspect-committed-state
                #:committed-state-classification
                #:marker-entry)
  (:export #:reference-transaction
           #:hook-error
           #:hook-error-reason
           #:hook-error-ref
           #:hook-error-detail
           #:hook-error-cause
           #:hook-configuration
           #:hook-configuration-p
           #:hook-configuration-status
           #:hook-configuration-detail
           #:hook-configuration-error
           #:hook-configuration-error-reason
           #:inspect-protection-hook
           #:ensure-protection-hook
           #:remove-protection-hook
           #:hook-disable-options))
