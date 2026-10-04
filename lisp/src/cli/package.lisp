(defpackage #:git-agent-workflow.cli
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow.commit
                #:commit)
  (:import-from #:git-agent-workflow.show
                #:show)
  (:import-from #:git-agent-workflow.check
                #:check
                #:check-report-ok-p
                #:write-check-report)
  (:import-from #:git-agent-workflow.status
                #:status
                #:diagnose-status
                #:status-report-ok-p
                #:write-status-report)
  (:import-from #:git-agent-workflow.deploy
                #:deploy
                #:deploy-result-branch
                #:deploy-result-mode
                #:deploy-result-worktree-path
                #:deploy-result-warnings)
  (:import-from #:git-agent-workflow.undeploy
                #:undeploy
                #:undeploy-result-ok-p
                #:undeploy-result-removed-selector-p
                #:undeploy-result-removed-legacy-refs
                #:undeploy-result-hook-cleared-p
                #:undeploy-result-residuals)
  (:import-from #:git-agent-workflow.init
                #:initialize
                #:init-result-branch
                #:init-result-commit-oid
                #:init-result-deploy-result)
  (:import-from #:git-agent-workflow.branch
                #:rename-branch
                #:delete-branch)
  (:import-from #:git-agent-workflow.help
                #:print-help)
  (:import-from #:git-agent-workflow.hook
                #:reference-transaction
                #:hook-error)
  (:export #:main))
