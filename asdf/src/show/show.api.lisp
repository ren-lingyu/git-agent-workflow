(in-package #:git-agent-workflow.show)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%show)
    (error "Required show API dependency is unavailable: ~S"
           '%show)))

(defun show (directory arguments)
  (%show directory arguments))
