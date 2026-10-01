(in-package #:git-agent-workflow.help)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%help-text)
    (error "Required help API dependency is unavailable: ~S" '%help-text)))

(defun print-help (topic &optional (stream *standard-output*))
  (write-string (%help-text topic) stream)
  topic)
