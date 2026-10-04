(defpackage #:git-agent-workflow.deploy
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
                #:current-ref
                #:protocol-refs)
  (:import-from #:git-agent-workflow.mutation
                #:select-source-ref
                #:restore-source-selection
                #:run-worktree)
  (:import-from #:git-agent-workflow.workspace
                #:list-worktrees
                #:worktree-record-path
                #:worktree-record-branch
                #:worktree-record-detached-p
                #:worktree-record-prunable-p)
  (:import-from #:git-agent-workflow.state
                #:inspect-committed-state
                #:committed-state-report-ok-p
                #:committed-state-report-findings
                #:committed-state-finding-status
                #:committed-state-finding-detail
                #:committed-state-marker-p
                #:local-branches)
  (:import-from #:git-agent-workflow.hook
                #:inspect-protection-hook
                #:hook-configuration-status
                #:hook-configuration-detail
                #:ensure-protection-hook)
  (:import-from #:git-agent-workflow.check
                #:check
                #:check-report-ok-p)
  (:export #:deploy
           #:deploy-error
           #:deploy-error-reason
           #:deploy-error-detail
           #:deploy-result
           #:deploy-result-p
           #:deploy-result-source-ref
           #:deploy-result-branch
           #:deploy-result-mode
           #:deploy-result-worktree-path
           #:deploy-result-warnings))
