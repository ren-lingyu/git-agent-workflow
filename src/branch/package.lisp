(defpackage #:git-agent-workflow.branch
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:make-ref
                #:inspect-ref
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-object-id
                #:registered-ref-p
                #:current-ref
                #:rename-ref-registration
                #:remove-ref-registration
                #:restore-ref-registration)
  (:import-from #:git-agent-workflow.workspace
                #:worktree-root
                #:current-local-head-ref)
  (:import-from #:git-agent-workflow.state
                #:inspect-committed-state
                #:committed-state-report-ok-p)
  (:export #:rename-branch
           #:delete-branch
           #:branch-error
           #:branch-error-reason
           #:branch-error-detail
           #:branch-result
           #:branch-result-p
           #:branch-result-operation
           #:branch-result-old-source-ref
           #:branch-result-new-source-ref))
