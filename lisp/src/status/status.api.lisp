(in-package #:git-agent-workflow.status)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%status-runtime %diagnose-status))
    (unless (fboundp function)
      (error "Required status runtime function is unavailable: ~S"
             function))))

(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *protocol-ref-prefix* "refs/gaw/")
(defparameter *legacy-ref-prefix* "refs/gaw/heads/")
(defparameter *selector-ref* "refs/gaw/HEAD")
(defparameter *diagnostic-git-arguments*
  '("fsck" "--connectivity-only" "--no-reflogs" "--no-dangling"
    "--no-progress"))

(defun status (directory)
  (%status-runtime directory *source-ref-prefix* *protocol-ref-prefix*
                   *legacy-ref-prefix* *selector-ref*))

(defun diagnose-status (directory)
  (%diagnose-status directory *diagnostic-git-arguments*))
