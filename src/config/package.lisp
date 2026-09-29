(defpackage #:git-agent-workflow.config
  (:use #:cl)
  (:import-from #:babel
                #:octets-to-string
                #:string-size-in-octets)
  (:import-from #:babel-encodings
                #:character-decoding-error)
  (:import-from #:git-agent-workflow.git
                #:run-git
                #:run-git-bytes
                #:git-invocation-stdout
                #:git-invocation-stderr
                #:git-invocation-exit-status)
  (:import-from #:git-agent-workflow.refs
                #:current-ref)
  (:export #:read-config
           #:config
           #:config-p
           #:config-workspace
           #:workspace-entry
           #:workspace-entry-p
           #:workspace-entry-kind
           #:workspace-entry-path
           #:config-error
           #:config-error-reason))
