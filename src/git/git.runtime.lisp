(in-package #:git-agent-workflow.git)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%make-git-invocation
                      %prepare-git-command))
    (unless (fboundp function)
      (error "Required Git core function is unavailable: ~S"
             function))))

(defun run-git (args directory)
  (multiple-value-bind (command arguments)
      (%prepare-git-command args
                            directory)
    (multiple-value-bind (stdout stderr exit-status)
        (uiop:run-program command
                          :output '(:string :stripped t)
                          :error-output '(:string :stripped t)
                          :ignore-error-status t
                          :force-shell nil)
      (%make-git-invocation :command command
                            :arguments arguments
                            :directory directory
                            :stdout stdout
                            :stderr stderr
                            :exit-status exit-status))))
