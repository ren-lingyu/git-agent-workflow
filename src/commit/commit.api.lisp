(in-package #:git-agent-workflow.commit)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%prepare-commit
                      %complete-commit
                      make-ref
                      inspect-ref
                      read-config-at-tree))
    (unless (fboundp function)
      (error "Required commit API dependency is unavailable: ~S"
             function))))

(defconstant +unix-to-universal-time-offset+
  2208988800)

(defparameter *reflog-message*
  "git-gaw commit")

(defparameter *identity-name*
  "Git Agent Workflow")

(defparameter *identity-email*
  "gaw@invalid")

(defun %ensure-registered-source-ref (source-ref directory)
  (let* ((registration-ref (make-ref source-ref))
         (state (inspect-ref registration-ref
                             directory)))
    (unless (ref-state-exists-p state)
      (%signal-commit-error :unregistered-branch
                            "The current branch is not registered with GAW"))
    (unless (and (ref-state-symbolic-p state)
                 (string= (ref-state-symbolic-target state)
                          source-ref))
      (%signal-commit-error :invalid-registration
                            "The current branch has an invalid GAW registration"))
    registration-ref))

(defun %workspace-declarations (config)
  (mapcar (lambda (entry)
            (cons (workspace-entry-kind entry)
                  (workspace-entry-path entry)))
          (config-workspace config)))

(defun commit (directory
               message
               &key
                 (project-commits '())
                 allow-empty
                 allow-empty-message)
  (unless (typep message
                 '(vector (unsigned-byte 8)))
    (error 'type-error
           :datum message
           :expected-type '(vector (unsigned-byte 8))))
  (unless (and (listp project-commits)
               (every #'stringp project-commits))
    (error 'type-error
           :datum project-commits
           :expected-type 'list))
  (when (and (zerop (length message))
             (not allow-empty-message))
    (%signal-commit-error :empty-message
                          "The commit message is empty"))
  (multiple-value-bind (root source-ref first-parent tree-oid entries)
      (%prepare-commit directory)
    (%ensure-registered-source-ref source-ref
                                   root)
    (%complete-commit root
                      source-ref
                      first-parent
                      tree-oid
                      entries
                      (%workspace-declarations
                       (read-config-at-tree root
                                            tree-oid))
                      message
                      project-commits
                      allow-empty
                      *reflog-message*
                      *identity-name*
                      *identity-email*
                      (- (get-universal-time)
                         +unix-to-universal-time-offset+))))
