(in-package #:git-agent-workflow.state)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%inspect-committed-state
                      %committed-state-marker-p
                      %marker-entry
                      %local-branches))
    (unless (fboundp function)
      (error "Required state API dependency is unavailable: ~S"
             function))))

(defparameter *config-path* ".gaw/config")

(defparameter *source-ref-prefix* "refs/heads/")

(defun inspect-committed-state (directory source-ref)
  (%inspect-committed-state directory source-ref *config-path*))

(defun committed-state-marker-p (directory source-ref)
  (%committed-state-marker-p directory source-ref *config-path*))

(defun marker-entry (directory revision)
  (%marker-entry directory revision *config-path*))

(defun local-branches (directory)
  (%local-branches directory *source-ref-prefix*))
