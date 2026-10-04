(defpackage #:git-agent-workflow/tests.refs
  (:use #:cl)
  (:import-from #:git-agent-workflow/tests
                #:call-git
                #:with-test-repository)
  (:import-from #:git-agent-workflow.refs
                #:inspect-ref
                #:ref-dangling-p
                #:protocol-refs
                #:select-source-ref
                #:restore-source-selection
                #:rename-selected-source
                #:delete-selector
                #:current-ref
                #:current-ref-error
                #:current-ref-error-reason
                #:ref-state-exists-p
                #:ref-state-symbolic-p
                #:ref-state-symbolic-target
                #:ref-state-object-id)
  (:export #:run-tests))
