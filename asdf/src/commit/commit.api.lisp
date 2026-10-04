(in-package #:git-agent-workflow.commit)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%commit-runtime)
    (error "Required commit API dependency is unavailable: ~S"
           '%commit-runtime)))

(defconstant +unix-to-universal-time-offset+
  2208988800)

(defparameter *reflog-message*
  "git-gaw commit")

(defparameter *identity-name*
  "Git Agent Workflow")

(defparameter *identity-email*
  "gaw@invalid")

(defun commit (directory
               message
               &key
                 (project-commits '())
                 allow-empty
                 allow-empty-message)
  (%commit-runtime directory message project-commits
                   allow-empty allow-empty-message
                   *reflog-message* *identity-name* *identity-email*
                   (lambda ()
                     (- (get-universal-time)
                        +unix-to-universal-time-offset+))))
