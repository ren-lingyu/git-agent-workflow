(in-package #:git-agent-workflow.undeploy)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%undeploy)
    (error "Required undeploy runtime function is unavailable")))

(defparameter *selector-ref* "refs/gaw/HEAD")
(defparameter *source-prefix* "refs/heads/")
(defparameter *legacy-prefix* "refs/gaw/heads/")
(defparameter *protocol-prefix* "refs/gaw/")

(defun undeploy (directory)
  (%undeploy directory *selector-ref* *source-prefix*
             *legacy-prefix* *protocol-prefix*))
