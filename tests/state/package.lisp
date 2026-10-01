(defpackage #:git-agent-workflow/tests.state
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository
                #:write-test-octets)
  (:import-from #:git-agent-workflow.state
                #:inspect-committed-state
                #:committed-state-report-ok-p
                #:committed-state-finding
                #:committed-state-finding-status)
  (:export #:run-tests))
