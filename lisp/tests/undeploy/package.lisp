(defpackage #:git-agent-workflow/tests.undeploy
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository)
  (:import-from #:git-agent-workflow.init #:initialize)
  (:import-from #:git-agent-workflow.undeploy
                #:undeploy
                #:undeploy-result-ok-p
                #:undeploy-result-removed-selector-p
                #:undeploy-result-removed-legacy-refs
                #:undeploy-result-residuals)
  (:export #:run-tests))
