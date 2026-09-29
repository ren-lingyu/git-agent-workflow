(in-package #:git-agent-workflow.git)

(defstruct (git-invocation (:constructor %make-git-invocation))
  command
  arguments
  directory
  stdout
  stderr
  exit-status)

(defun %prepare-git-command (args directory)
  (check-type directory
              pathname)
  (assert (every #'stringp
                 args)
          (args)
          "Git arguments must be strings: ~S"
          args)
  (let ((arguments (copy-list
                    args)))
    (values (concatenate 'list
                         (list "git"
                               "-C"
                               (namestring directory))
                         arguments)
            arguments)))
