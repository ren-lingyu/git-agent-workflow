(defpackage #:git-agent-workflow/tests.init
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository
                #:with-temporary-directory)
  (:import-from #:git-agent-workflow.init
                #:initialize
                #:init-error
                #:init-error-reason
                #:init-result-commit-oid)
  (:import-from #:git-agent-workflow.refs
                #:current-ref
                #:registered-ref-p
                #:protocol-refs)
  (:import-from #:git-agent-workflow.check
                #:check
                #:check-report-ok-p)
  (:export #:run-tests))
