(in-package #:git-agent-workflow.check)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git worktree-root current-local-head-ref
                      operation-states configured-identity read-tree-snapshot
                      read-index-snapshot validate-snapshot-shape
                      validate-workspace find-project-path-conflict
                      read-config-at-tree read-config-blob))
    (unless (fboundp function)
      (error "Required check runtime dependency is unavailable: ~S" function))))

(defun %successful-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %canonical-directory (directory)
  (check-type directory pathname)
  (uiop:ensure-directory-pathname (truename directory)))

(defun %resolve-head-commit (directory)
  (let ((invocation
          (run-git '("rev-parse" "--verify" "--end-of-options" "HEAD^{commit}")
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (return-from %resolve-head-commit nil))
    (git-invocation-stdout invocation)))

(defun %resolve-tree (commit-oid directory)
  (%successful-stdout
   (run-git (list "rev-parse" "--verify" "--end-of-options"
                  (concatenate 'string commit-oid "^{tree}"))
            directory)
   "resolving a commit tree"))

(defun %commit-parents (commit-oid directory)
  (let* ((line (%successful-stdout
                (run-git (list "rev-list" "--parents" "-n" "1" commit-oid)
                         directory)
                "reading GAW commit parents"))
         (fields (uiop:split-string line :separator '(#\Space))))
    (unless (and fields (string= (first fields) commit-oid))
      (error "Git returned malformed parent output"))
    (rest fields)))

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

(defun %check-project-parents (commit-oid workspace directory)
  (dolist (parent (rest (%commit-parents commit-oid directory)))
    (let* ((tree-oid (%resolve-tree parent directory))
           (entries (read-tree-snapshot directory tree-oid)))
      (when (find-project-path-conflict workspace entries)
        (return-from %check-project-parents
          (values nil
                  "An associated project parent tracks a reserved or workspace path")))))
  (values t "The associated project parent trees are disjoint"))

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
        (source-ref nil)
        (head-oid nil)
        (head-tree nil)
        (head-workspace nil)
        (head-config-valid-p nil))
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
                        :head-workspace :project-parents :index :identity
                        :operation-state))
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
          (progn
            (setf head-oid (%resolve-head-commit root))
            (if head-oid
                (record :head :ok "HEAD resolves to a commit")
                (record :head :error "The current GAW branch is unborn")))
          (skip :head "Skipped because no local branch is available"))

      (when head-oid
        (setf head-tree (%resolve-tree head-oid root))
        (handler-case
            (let ((config (read-config-at-tree root head-tree)))
              (setf head-workspace (%workspace-declarations config)
                    head-config-valid-p t)
              (record :head-config :ok "HEAD contains a valid .gaw/config"))
          (config-error (condition)
            (record :head-config :error
                    (format nil "Invalid HEAD config: ~A" condition)))))
      (unless head-oid
        (skip :head-config "Skipped because HEAD does not resolve to a commit"))

      (if head-config-valid-p
          (handler-case
              (progn
                (validate-workspace head-workspace
                                    (read-tree-snapshot root head-tree))
                (record :head-workspace :ok
                        "HEAD satisfies its workspace declaration"))
            (workspace-error (condition)
              (record :head-workspace :error
                      (or (workspace-error-detail condition)
                          (format nil "~A" condition)))))
          (skip :head-workspace "Skipped because HEAD config is unavailable"))

      (if head-config-valid-p
          (multiple-value-bind (ok detail)
              (%check-project-parents head-oid head-workspace root)
            (record :project-parents (if ok :ok :error) detail))
          (skip :project-parents "Skipped because HEAD config is unavailable"))

      (multiple-value-bind (ok detail)
          (%check-index root config-path)
        (record :index (if ok :ok :error) detail))

      (handler-case
          (progn
            (multiple-value-bind (name email)
                (configured-identity root)
              (declare (ignore name email)))
            (record :identity :ok
                    "Repository/worktree-local Git identity is configured"))
        (workspace-error (condition)
          (record :identity :error
                  (or (workspace-error-detail condition)
                      "Git identity is not configured"))))

      (let ((states (operation-states root)))
        (if states
            (record :operation-state :error
                    (format nil "Git operation state is present: ~{~A~^, ~}"
                            states))
            (record :operation-state :ok
                    "No conflicting Git operation is in progress")))
      (finish))))
