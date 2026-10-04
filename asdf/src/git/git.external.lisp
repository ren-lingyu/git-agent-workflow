(in-package #:git-agent-workflow.git)

(defun %external-git-program ()
  (load-time-value
   (let ((program (uiop:getenv "GIT")))
     (if (and program
              (plusp (length program)))
         program
         "git"))
   t))
