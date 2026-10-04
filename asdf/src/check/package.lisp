(defpackage #:git-agent-workflow.check
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:current-ref
                #:inspect-ref
                #:ref-state-exists-p)
  (:import-from #:git-agent-workflow.config
                #:read-config-blob
                #:config-workspace
                #:workspace-entry-kind
                #:workspace-entry-path
                #:config-error)
  (:import-from #:git-agent-workflow.workspace
                #:worktree-root
                #:current-local-head-ref
                #:operation-states
                #:read-index-snapshot
                #:validate-snapshot-shape
                #:validate-workspace
                #:entry-at-path
                #:git-entry-mode
                #:git-entry-type
                #:git-entry-object-id
                #:git-entry-stage
                #:workspace-error
                #:workspace-error-detail)
  (:import-from #:git-agent-workflow.state
                #:inspect-committed-state
                #:committed-state-report-ok-p
                #:committed-state-report-findings
                #:committed-state-finding-name
                #:committed-state-finding-status
                #:committed-state-finding-detail)
  (:import-from #:git-agent-workflow.hook
                #:inspect-protection-hook
                #:hook-configuration-status
                #:hook-configuration-detail)
  (:export #:check
           #:write-check-report
           #:check-report
           #:check-report-p
           #:check-report-root
           #:check-report-findings
           #:check-report-ok-p
           #:check-finding
           #:check-finding-p
           #:check-finding-name
           #:check-finding-status
           #:check-finding-detail
           #:check-error
           #:check-error-reason))
