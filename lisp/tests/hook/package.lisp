(defpackage #:git-agent-workflow/tests.hook
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository
                #:write-test-octets)
  (:import-from #:git-agent-workflow.hook
                #:reference-transaction
                #:hook-error
                #:hook-error-reason
                #:hook-configuration-status
                #:hook-configuration-error
                #:hook-configuration-error-reason
                #:inspect-protection-hook
                #:ensure-protection-hook)
  (:export #:run-tests))
