(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%current-ref)
    (error "Required current ref runtime function is unavailable: ~S"
           '%current-ref))
  (dolist (variable '(*display-name*
                      *source-ref-prefix*
                      *target-ref-prefix*))
    (unless (boundp variable)
      (error "Required refs variable is unavailable: ~S"
             variable))))

(defparameter *head-ref*
  "refs/gaw/HEAD")

(defun current-ref (directory)
  (%current-ref directory
                *display-name*
                *head-ref*
                *source-ref-prefix*
                *target-ref-prefix*))
