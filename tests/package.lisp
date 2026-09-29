(defpackage #:git-agent-workflow/tests
  (:use #:cl)
  (:export #:signals
           #:call-git
           #:with-temporary-directory
           #:with-test-repository
           #:run-tests))

(defpackage #:git-agent-workflow/tests.git
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:with-temporary-directory
                #:with-test-repository)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:git-invocation
                #:git-invocation-command
                #:git-invocation-arguments
                #:git-invocation-directory
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:export #:run-tests))

(defpackage #:git-agent-workflow/tests.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:signals
                #:call-git
                #:with-test-repository)
  (:import-from #:git-agent-workflow.refs
                #:make-ref
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
