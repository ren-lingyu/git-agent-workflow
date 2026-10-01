(defpackage #:git-agent-workflow/tests.deploy
  (:use #:cl)
  (:import-from #:babel #:string-to-octets)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository
                #:with-temporary-directory
                #:write-test-octets
                #:signals)
  (:import-from #:git-agent-workflow.deploy
                #:deploy
                #:deploy-error
                #:deploy-error-reason
                #:deploy-result-mode
                #:deploy-result-branch
                #:deploy-result-worktree-path
                #:deploy-result-warnings)
  (:import-from #:git-agent-workflow.refs
                #:current-ref
                #:registered-ref-p)
  (:import-from #:git-agent-workflow.hook
                #:inspect-protection-hook
                #:hook-configuration-status)
  (:import-from #:git-agent-workflow.check
                #:check
                #:check-report-ok-p)
  (:export #:run-tests))
