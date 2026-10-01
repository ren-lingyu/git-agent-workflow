(in-package #:git-agent-workflow.init)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%initialize)
    (error "Required init API dependency is unavailable: ~S" '%initialize)))

(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *initial-config* (format nil "(:workspace ())~%"))
(defparameter *initial-message* "Initialize GAW")
(defparameter *identity-name* "Git Agent Workflow")
(defparameter *identity-email* "gaw@invalid")

(defun initialize (directory &key branch worktree-path)
  (unless branch
    (%signal-init-error :missing-branch "--branch is required"))
  (%initialize directory branch worktree-path *source-ref-prefix*
               *initial-config* *initial-message*
               *identity-name* *identity-email*))
