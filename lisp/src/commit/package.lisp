(defpackage #:git-agent-workflow.commit
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:run-git-bytes
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:make-ref
                #:inspect-ref
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target)
  (:import-from #:git-agent-workflow.config
                #:read-config-at-tree
                #:config-workspace
                #:workspace-entry-kind
                #:workspace-entry-path)
  (:import-from #:git-agent-workflow.workspace
                #:worktree-root
                #:current-local-head-ref
                #:operation-states
                #:read-tree-snapshot
                #:validate-workspace
                #:find-project-path-conflict
                #:workspace-error
                #:workspace-error-reason
                #:workspace-error-detail)
  (:export #:commit
           #:commit-error
           #:commit-error-reason))
