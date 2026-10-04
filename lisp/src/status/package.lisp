(defpackage #:git-agent-workflow.status
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:run-git-passthrough
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:protocol-refs
                #:inspect-ref
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target
                #:ref-state-object-id)
  (:import-from #:git-agent-workflow.state
                #:local-branches
                #:committed-state-marker-p
                #:inspect-committed-state
                #:committed-state-report-ok-p
                #:committed-state-report-commit-oid
                #:committed-state-report-findings
                #:committed-state-finding-status
                #:committed-state-finding-detail)
  (:import-from #:git-agent-workflow.workspace
                #:list-worktrees
                #:worktree-record-path
                #:worktree-record-branch
                #:worktree-record-detached-p
                #:worktree-record-bare-p
                #:worktree-record-prunable-p)
  (:import-from #:git-agent-workflow.hook
                #:inspect-protection-hook
                #:hook-configuration-status
                #:hook-configuration-detail)
  (:export #:status
           #:diagnose-status
           #:write-status-report
           #:status-report
           #:status-report-p
           #:status-report-ok-p
           #:status-report-repository
           #:status-report-branches
           #:status-report-protocol-refs
           #:status-report-selector
           #:status-report-worktrees
           #:status-report-hook
           #:status-branch
           #:status-branch-p
           #:status-branch-ref
           #:status-branch-object-id
           #:status-branch-classification
           #:status-branch-committed-state
           #:status-protocol-ref
           #:status-protocol-ref-p
           #:status-protocol-ref-name
           #:status-protocol-ref-kind
           #:status-protocol-ref-value
           #:status-protocol-ref-status
           #:status-protocol-ref-detail
           #:status-error
           #:status-error-reason))
