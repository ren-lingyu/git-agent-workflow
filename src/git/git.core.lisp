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

(defun %environment-entry-name (entry)
  (let ((separator (position #\= entry)))
    (if separator
        (subseq entry 0 separator)
        entry)))

(defun %git-environment-name-p (name)
  (and (>= (length name) 4)
       (string= "GIT_" name :end2 4)))

(defun %protected-git-environment-name-p (name)
  (member name
          '("GIT_CONFIG_NOSYSTEM"
            "GIT_CONFIG_SYSTEM"
            "GIT_CONFIG_GLOBAL")
          :test #'string=))

(defun %validate-git-environment (environment)
  (dolist (binding environment)
    (unless (and (consp binding)
                 (stringp (car binding))
                 (stringp (cdr binding))
                 (plusp (length (car binding)))
                 (not (position #\= (car binding))))
      (error "Invalid Git environment binding: ~S"
             binding))
    (when (%protected-git-environment-name-p (car binding))
      (error "Git environment binding is protected: ~S"
             (car binding))))
  environment)
