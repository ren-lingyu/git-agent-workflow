(defpackage #:git-agent-workflow.cli
  (:use #:cl)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:git-agent-workflow.commit
                #:commit)
  (:export #:main))
