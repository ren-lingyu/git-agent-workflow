(defpackage #:git-agent-workflow.undeploy
  (:use #:cl)
  (:import-from #:git-agent-workflow.git
                #:run-git #:git-invocation-exit-status
                #:git-invocation-stderr)
  (:import-from #:git-agent-workflow.refs
                #:inspect-ref #:protocol-refs
                #:ref-state-exists-p #:ref-state-symbolic-p
                #:ref-state-symbolic-target)
  (:import-from #:git-agent-workflow.state #:local-branches)
  (:import-from #:git-agent-workflow.mutation
                #:delete-selector #:delete-symbolic-ref)
  (:import-from #:git-agent-workflow.hook #:remove-protection-hook)
  (:export #:undeploy #:undeploy-result #:undeploy-result-p
           #:undeploy-result-removed-selector-p
           #:undeploy-result-removed-legacy-refs
           #:undeploy-result-hook-cleared-p
           #:undeploy-result-residuals
           #:undeploy-result-ok-p))
