(in-package #:git-agent-workflow.git)

(defstruct (git-invocation (:constructor %make-git-invocation))
  command
  arguments
  directory
  stdout
  stderr
  exit-status)

(defun run-git (args directory)
  (check-type directory
              pathname)
  (assert (every #'stringp
                 args)
          (args)
          "Git arguments must be strings: ~S"
          args)
  (let* ((arguments (copy-list
                     args))
         (command (concatenate 'list
                               (list "git"
                                     "-C"
                                     (namestring directory))
                               arguments)))
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
