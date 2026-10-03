(in-package #:git-agent-workflow.cli)

(defun %cli-error (control &rest arguments)
  (error (apply #'format nil control arguments)))

(defun %option-value (argument long-name short-name arguments)
  (cond
    ((or (string= argument long-name)
         (string= argument short-name))
     (unless arguments
       (%cli-error "Option ~A requires a value" argument))
     (values (first arguments) (rest arguments)))
    ((and (> (length argument) (length short-name))
          (string= short-name argument :end2 (length short-name)))
     (values (subseq argument (length short-name)) arguments))
    ((let ((prefix (concatenate 'string long-name "=")))
       (and (>= (length argument) (length prefix))
            (string= prefix argument :end2 (length prefix))))
     (values (subseq argument (1+ (length long-name))) arguments))
    (t
     (values nil arguments))))

(defun %long-option-value (argument name arguments)
  (cond
    ((string= argument name)
     (unless arguments
       (%cli-error "Option ~A requires a value" name))
     (values (first arguments) (rest arguments)))
    ((let ((prefix (concatenate 'string name "=")))
       (and (>= (length argument) (length prefix))
            (string= prefix argument :end2 (length prefix))))
     (values (subseq argument (1+ (length name))) arguments))
    (t (values nil arguments))))

(defun %parse-commit-options (arguments)
  (let ((fragments '())
        (project-commits '())
        (allow-empty nil)
        (allow-empty-message nil)
        (options-p t))
    (loop while arguments
          for argument = (pop arguments)
          do (cond
               ((and options-p (string= argument "--"))
                (setf options-p nil))
               ((and options-p (string= argument "--allow-empty"))
                (setf allow-empty t))
               ((and options-p (string= argument "--allow-empty-message"))
                (setf allow-empty-message t))
               (options-p
                (multiple-value-bind (message remaining)
                    (%option-value argument "--message" "-m" arguments)
                  (if message
                      (setf arguments remaining
                            fragments (nconc fragments
                                             (list (cons :message message))))
                      (multiple-value-bind (file file-remaining)
                          (%option-value argument "--file" "-F" arguments)
                        (cond
                          (file
                           (setf arguments file-remaining
                                 fragments (nconc fragments
                                                  (list (cons :file file)))))
                          ((and (plusp (length argument))
                                (char= (char argument 0) #\-))
                           (%cli-error "Unsupported commit option: ~A"
                                       argument))
                          (t
                           (setf project-commits
                                 (nconc project-commits
                                        (list argument)))))))))
               (t
                (setf project-commits
                      (nconc project-commits (list argument))))))
    (unless fragments
      (%cli-error "git gaw commit requires -m or -F"))
    (values fragments project-commits allow-empty allow-empty-message)))

(defun %parse-deploy-arguments (arguments)
  (let ((branch nil) (worktree-path nil))
    (loop while arguments
          for argument = (pop arguments)
          do (multiple-value-bind (value remaining)
                 (%long-option-value argument "--branch" arguments)
               (if value
                   (progn
                     (when branch
                       (%cli-error "Option --branch may be specified only once"))
                     (setf branch value arguments remaining))
                   (multiple-value-bind (path path-remaining)
                       (%long-option-value argument "--worktree-path" arguments)
                     (if path
                         (progn
                           (when worktree-path
                             (%cli-error
                              "Option --worktree-path may be specified only once"))
                           (setf worktree-path path
                                 arguments path-remaining))
                         (%cli-error "Unsupported deploy argument: ~A"
                                     argument))))))
    (values branch worktree-path)))

(defun %help-topic (name)
  (cond
    ((string= name "commit") :commit)
    ((string= name "show") :show)
    ((string= name "check") :check)
    ((string= name "status") :status)
    ((string= name "deploy") :deploy)
    ((string= name "init") :init)
    ((string= name "branch") :branch)
    (t (%cli-error "Unknown help topic: ~A" name))))

(defun %usage-error ()
  (%cli-error
   "Usage:~%  git gaw init --branch <name> [--worktree-path <path>]~%  git gaw deploy [--branch <name>] [--worktree-path <path>]~%  git gaw branch -m <new-name> | -d <name>~%  git gaw commit [options] [--] [project-commit...]~%  git gaw show [options] [object...] [-- path...]~%  git gaw check~%  git gaw status [--diagnose]~%  git gaw help [init|deploy|branch|commit|show|check|status]"))

(defun %sole-help-option-p (arguments)
  (and arguments
       (null (rest arguments))
       (string= (first arguments) "--help")))
