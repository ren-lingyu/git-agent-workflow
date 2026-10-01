(in-package #:git-agent-workflow.check)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git worktree-root current-local-head-ref
                      operation-states inspect-committed-state
                      read-index-snapshot validate-snapshot-shape
                      validate-workspace read-config-blob
                      inspect-protection-hook
                      hook-configuration-status
                      hook-configuration-detail))
    (unless (fboundp function)
      (error "Required check runtime dependency is unavailable: ~S" function))))

(defun %canonical-directory (directory)
  (check-type directory pathname)
  (uiop:ensure-directory-pathname (truename directory)))

(defun %workspace-declarations (config)
  (mapcar (lambda (entry)
            (cons (workspace-entry-kind entry)
                  (workspace-entry-path entry)))
          (config-workspace config)))

(defun %check-registration (source-ref directory)
  (let* ((registration-ref (make-ref source-ref))
         (state (inspect-ref registration-ref directory)))
    (cond
      ((not (ref-state-exists-p state))
       (values nil "The current branch is not registered with GAW"))
      ((not (and (ref-state-symbolic-p state)
                 (string= (ref-state-symbolic-target state) source-ref)))
       (values nil "The current branch has an invalid GAW registration"))
      (t
       (values t "The current branch registration is valid")))))

(defun %index-config-entry (entries config-path)
  (entry-at-path (string-to-octets config-path :encoding :utf-8) entries))

(defun %check-index (directory config-path)
  (handler-case
      (let ((entries (read-index-snapshot directory)))
        (validate-snapshot-shape entries)
        (let ((entry (%index-config-entry entries config-path)))
          (unless entry
            (return-from %check-index
              (values nil "The staged candidate has no .gaw/config")))
          (unless (and (zerop (git-entry-stage entry))
                       (string= (git-entry-mode entry) "100644")
                       (string= (git-entry-type entry) "blob")
                       (plusp (length (git-entry-object-id entry))))
            (return-from %check-index
              (values nil "The staged .gaw/config is not a 100644 blob")))
          (let* ((config (read-config-blob directory
                                           (git-entry-object-id entry)))
                 (workspace (%workspace-declarations config)))
            (validate-workspace workspace entries)
            (values t "The staged candidate satisfies its workspace declaration"))))
    (config-error (condition)
      (values nil (format nil "Invalid staged config: ~A" condition)))
    (workspace-error (condition)
      (values nil (or (workspace-error-detail condition)
                      (format nil "~A" condition))))))

(defun %check-runtime (directory config-path)
  (let ((findings '())
        (root nil)
        (source-ref nil))
    (labels ((record (name status detail)
               (push (%make-check-finding name status detail) findings))
             (skip (name detail)
               (record name :skipped detail))
             (finish ()
               (%make-check-report root (nreverse findings))))
      (handler-case
          (setf root (worktree-root directory))
        (workspace-error (condition)
          (record :worktree :error
                  (or (workspace-error-detail condition)
                      "The directory is not a Git worktree"))))
      (unless root
        (dolist (name '(:branch :registration :head :head-config
                        :head-workspace :project-parents :index
                        :operation-state :protection-hook))
          (skip name "Skipped because no Git worktree is available"))
        (return-from %check-runtime (finish)))

      (if (equal (namestring (%canonical-directory directory))
                 (namestring root))
          (record :worktree :ok (format nil "Worktree root: ~A" root))
          (record :worktree :warning
                  (format nil "Worktree root: ~A; git gaw commit must run there"
                          root)))

      (handler-case
          (progn
            (setf source-ref (current-local-head-ref root))
            (record :branch :ok source-ref))
        (workspace-error (condition)
          (record :branch :error
                  (or (workspace-error-detail condition)
                      "HEAD is not a local branch"))))

      (if source-ref
          (multiple-value-bind (ok detail)
              (%check-registration source-ref root)
            (record :registration (if ok :ok :error) detail))
          (skip :registration "Skipped because no local branch is available"))

      (if source-ref
          (dolist (finding
                    (committed-state-report-findings
                     (inspect-committed-state root source-ref)))
            (record (committed-state-finding-name finding)
                    (committed-state-finding-status finding)
                    (committed-state-finding-detail finding)))
          (dolist (name '(:head :head-config :head-workspace
                          :project-parents))
            (skip name "Skipped because no local branch is available")))

      (multiple-value-bind (ok detail)
          (%check-index root config-path)
        (record :index (if ok :ok :error) detail))

      (let ((states (operation-states root)))
        (if states
            (record :operation-state :error
                    (format nil "Git operation state is present: ~{~A~^, ~}"
                            states))
            (record :operation-state :ok
                    "No conflicting Git operation is in progress")))

      (handler-case
          (let ((configuration (inspect-protection-hook root)))
            (if (eq :canonical
                    (hook-configuration-status configuration))
                (record :protection-hook :ok
                        (hook-configuration-detail configuration))
                (record :protection-hook :warning
                        (hook-configuration-detail configuration))))
        (error (condition)
          (record :protection-hook :warning
                  (format nil "Cannot inspect the optional protection hook: ~A"
                          condition))))
      (finish))))
