(defpackage #:git-agent-workflow/tests.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:signals
                #:call-git
                #:with-test-repository)
  (:import-from #:git-agent-workflow.refs
                #:make-ref
                #:registered-ref-p
                #:registration-error
                #:registration-error-reason
                #:inspect-ref
                #:ref-dangling-p
                #:register-ref
                #:unregister-ref
                #:current-ref
                #:current-ref-error
                #:current-ref-error-reason
                #:ref-state-name
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target)
  (:export #:run-tests))
