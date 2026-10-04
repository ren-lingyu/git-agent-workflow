(in-package #:git-agent-workflow.deploy)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%deploy)
    (error "Required deploy API dependency is unavailable: ~S" '%deploy)))

(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *legacy-ref-prefix* "refs/gaw/heads/")
(defparameter *head-ref* "refs/gaw/HEAD")

(defun deploy (directory &key branch worktree-path)
  (%deploy directory branch worktree-path
           *source-ref-prefix* *legacy-ref-prefix* *head-ref*))
