(defpackage #:git-agent-workflow.hook
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:registered-ref-p
                #:registration-error
                #:inspect-ref
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target)
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
           #:hook-disable-options))
