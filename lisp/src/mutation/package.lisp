(defpackage #:git-agent-workflow.mutation
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git)
  (:import-from #:git-agent-workflow.hook
                #:hook-disable-options)
  (:export #:select-source-ref
           #:restore-source-selection
           #:initialize-source-and-selector
           #:remove-initial-source-and-selector
           #:rename-selected-source
           #:delete-selector
           #:delete-symbolic-ref
           #:run-branch
           #:run-worktree
           #:run-source-ref-update))
