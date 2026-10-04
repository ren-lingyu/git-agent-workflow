(in-package #:git-agent-workflow.cli)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%main-status)
    (error "Required CLI runtime function is unavailable: ~S"
           '%main-status)))

(defun main ()
  (uiop:quit (%main-status)))
