(defpackage #:git-agent-workflow.state
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.config
                #:read-config-at-tree
                #:config-workspace
                #:workspace-entry-kind
                #:workspace-entry-path
                #:config-error)
  (:import-from #:git-agent-workflow.workspace
                #:read-tree-snapshot
                #:validate-workspace
                #:find-project-path-conflict
                #:workspace-error
                #:workspace-error-reason
                #:workspace-error-detail)
  (:export #:inspect-committed-state
           #:committed-state-marker-p
           #:local-branches
           #:committed-state-report
           #:committed-state-report-p
           #:committed-state-report-source-ref
           #:committed-state-report-commit-oid
           #:committed-state-report-tree-oid
           #:committed-state-report-config
           #:committed-state-report-workspace
           #:committed-state-report-findings
           #:committed-state-report-ok-p
           #:committed-state-classification
           #:marker-entry
           #:committed-state-finding
           #:committed-state-finding-p
           #:committed-state-finding-name
           #:committed-state-finding-status
           #:committed-state-finding-certainty
           #:committed-state-finding-detail))
