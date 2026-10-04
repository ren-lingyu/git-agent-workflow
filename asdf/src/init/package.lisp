(defpackage #:git-agent-workflow.init
  (:use #:cl)
  (:import-from #:babel #:string-to-octets)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:inspect-ref
                #:ref-state-exists-p
                #:protocol-refs)
  (:import-from #:git-agent-workflow.mutation
                #:initialize-source-and-selector
                #:remove-initial-source-and-selector)
  (:import-from #:git-agent-workflow.state
                #:local-branches
                #:committed-state-marker-p
                #:inspect-committed-state
                #:committed-state-report-ok-p)
  (:import-from #:git-agent-workflow.hook
                #:inspect-protection-hook
                #:hook-configuration-status
                #:hook-configuration-detail)
  (:import-from #:git-agent-workflow.deploy
                #:deploy
                #:deploy-result-mode
                #:deploy-result-worktree-path)
  (:export #:initialize
           #:init-error
           #:init-error-reason
           #:init-error-detail
           #:init-result
           #:init-result-p
           #:init-result-source-ref
           #:init-result-branch
           #:init-result-commit-oid
           #:init-result-deploy-result))
