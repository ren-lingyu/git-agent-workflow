(defpackage #:git-agent-workflow/tests.cli
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:with-temporary-directory
                #:with-test-repository
                #:call-git
                #:write-test-octets)
  (:export #:run-tests))
