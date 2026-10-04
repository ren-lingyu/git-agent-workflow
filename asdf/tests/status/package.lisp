(defpackage #:git-agent-workflow/tests.status
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:write-test-octets
                #:with-test-repository
                #:with-temporary-directory)
  (:import-from #:git-agent-workflow.status
                #:status
                #:diagnose-status
                #:write-status-report
                #:status-report-ok-p
                #:status-report-branches
                #:status-report-protocol-refs
                #:status-report-selector
                #:status-report-worktrees
                #:status-branch-ref
                #:status-branch-classification
                #:status-protocol-ref-name
                #:status-protocol-ref-status
                #:status-protocol-ref-kind)
  (:import-from #:git-agent-workflow.init
                #:initialize)
  (:export #:run-tests))
