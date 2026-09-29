(in-package #:git-agent-workflow.show)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git-passthrough
                      %prepare-show-arguments))
    (unless (fboundp function)
      (error "Required show runtime dependency is unavailable: ~S"
             function))))

(defun %show (directory arguments)
  (git-invocation-exit-status
   (run-git-passthrough (%prepare-show-arguments arguments)
                        directory
                        :git-environment
                        '(("GIT_PAGER" . "")))))
