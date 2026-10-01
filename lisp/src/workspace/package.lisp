(defpackage #:git-agent-workflow.workspace
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:run-git-bytes
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:export #:worktree-root
           #:current-local-head-ref
           #:operation-states
           #:read-tree-snapshot
           #:read-index-snapshot
           #:validate-snapshot-shape
           #:validate-workspace
           #:find-project-path-conflict
           #:entry-at-path
           #:git-entry
           #:git-entry-p
           #:git-entry-mode
           #:git-entry-type
           #:git-entry-object-id
           #:git-entry-path
           #:git-entry-stage
           #:workspace-error
           #:workspace-error-reason
           #:workspace-error-detail))
