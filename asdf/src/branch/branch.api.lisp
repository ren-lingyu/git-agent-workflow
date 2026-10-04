(in-package #:git-agent-workflow.branch)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%rename-branch %delete-branch))
    (unless (fboundp function)
      (error "Required branch API dependency is unavailable: ~S" function))))

(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *selector-ref* "refs/gaw/HEAD")

(defun rename-branch (directory new-name)
  (%rename-branch directory new-name *source-ref-prefix*))

(defun delete-branch (directory name)
  (%delete-branch directory name *source-ref-prefix* *selector-ref*))
