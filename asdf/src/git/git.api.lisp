(in-package #:git-agent-workflow.git)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%external-git-program
                      %run-git
                      %run-git-bytes
                      %run-git-passthrough))
    (unless (fboundp function)
      (error "Required Git API dependency is unavailable: ~S"
             function))))

(defun run-git (args directory &key input git-environment)
  (%run-git (%external-git-program)
            args
            directory
            :input input
            :git-environment git-environment))

(defun run-git-bytes (args directory &key input git-environment)
  (%run-git-bytes (%external-git-program)
                  args
                  directory
                  :input input
                  :git-environment git-environment))

(defun run-git-passthrough (args directory &key git-environment)
  (%run-git-passthrough (%external-git-program)
                        args
                        directory
                        :git-environment git-environment))
