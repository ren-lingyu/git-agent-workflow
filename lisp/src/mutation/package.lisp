(defpackage #:git-agent-workflow.mutation
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git)
  (:import-from #:git-agent-workflow.hook
                #:hook-disable-options)
  (:export #:register-ref
           #:unregister-ref
           #:select-ref
           #:restore-selection
           #:initialize-ref-graph
           #:remove-initial-ref-graph
           #:rename-ref-registration
           #:remove-ref-registration
           #:restore-ref-registration
           #:run-branch
           #:run-worktree
           #:run-source-ref-update))
