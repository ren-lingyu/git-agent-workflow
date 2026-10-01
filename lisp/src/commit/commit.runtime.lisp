(in-package #:git-agent-workflow.commit)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      run-git-bytes
                      %signal-commit-error
                      %call-with-workspace-error-as-commit-error
                      worktree-root
                      current-local-head-ref
                      operation-states
                      read-tree-snapshot
                      validate-workspace
                      find-project-path-conflict))
    (unless (fboundp function)
      (error "Required commit runtime dependency is unavailable: ~S"
             function))))

(defun %successful-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation
           (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %canonical-directory (directory)
  (check-type directory
              pathname)
  (handler-case
      (uiop:ensure-directory-pathname
       (truename directory))
    (file-error ()
      (%signal-commit-error :not-worktree-root
                            "The commit directory does not exist"))))

(defun %ensure-worktree-root (directory)
  (let ((root-path
          (handler-case
              (worktree-root directory)
            (workspace-error (condition)
              (%signal-commit-error
               :not-worktree-root
               "~A"
               (or (workspace-error-detail condition) condition))))))
    (unless (equal (namestring (%canonical-directory directory))
                   (namestring root-path))
      (%signal-commit-error :not-worktree-root
                            "git gaw commit must run at the worktree root"))
    root-path))

(defun %current-head-ref (directory)
  (%call-with-workspace-error-as-commit-error
   (lambda () (current-local-head-ref directory))))

(defun %resolve-commit-revision (revision directory operation)
  (check-type revision
              string)
  (let* ((commit-revision (concatenate 'string
                                       revision
                                       "^{commit}"))
         (invocation
           (run-git (list "rev-parse"
                          "--verify"
                          "--end-of-options"
                          commit-revision)
                    directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-commit-error :invalid-project-commit
                            "Cannot resolve project commit ~S"
                            revision))
    (let ((oid (git-invocation-stdout invocation)))
      (when (zerop (length oid))
        (error "Git returned an empty commit object ID while ~A"
               operation))
      oid)))

(defun %resolve-first-parent (source-ref directory)
  (let* ((revision (concatenate 'string
                                source-ref
                                "^{commit}"))
         (invocation
           (run-git (list "rev-parse"
                          "--verify"
                          "--end-of-options"
                          revision)
                    directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-commit-error :detached-head
                            "The current GAW branch is unborn"))
    (git-invocation-stdout invocation)))

(defun %resolve-tree (commit-oid directory)
  (%successful-stdout
   (run-git (list "rev-parse"
                  "--verify"
                  "--end-of-options"
                  (concatenate 'string
                               commit-oid
                               "^{tree}"))
            directory)
   "resolving a commit tree"))

(defun %ensure-no-operation-in-progress (directory)
  (let ((states (operation-states directory)))
    (when states
      (%signal-commit-error :operation-in-progress
                            "Git operation state is present: ~A"
                            (first states)))))

(defun %ensure-merged-index (directory)
  (let ((invocation
          (run-git-bytes '("ls-files" "-u" "-z")
                         directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Git failed while inspecting the index: ~A"
             (git-invocation-stderr invocation)))
    (when (plusp (length (git-invocation-stdout invocation)))
      (%signal-commit-error :unmerged-index
                            "The index contains unmerged entries"))))

(defun %write-tree (directory)
  (%successful-stdout
   (run-git '("write-tree")
            directory)
   "writing the staged GAW tree"))

(defun %tree-entries (tree-oid directory)
  (read-tree-snapshot directory tree-oid))

(defun %resolve-project-commits (revisions first-parent directory)
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (revision revisions
                      (nreverse result))
      (let ((oid (%resolve-commit-revision revision
                                           directory
                                           "resolving a project commit")))
        (when (string= oid first-parent)
          (%signal-commit-error :duplicate-parent
                                "A project parent equals the GAW first parent"))
        (when (gethash oid seen)
          (%signal-commit-error :duplicate-parent
                                "A project parent was supplied more than once"))
        (setf (gethash oid seen)
              t)
        (push oid result)))))

(defun %ensure-project-paths-disjoint (workspace
                                       project-commits
                                       directory)
  (dolist (commit-oid project-commits)
    (let* ((tree-oid (%resolve-tree commit-oid
                                    directory))
           (conflict
             (find-project-path-conflict
              workspace
              (%tree-entries tree-oid directory))))
      (when conflict
        (%signal-commit-error :path-conflict
                              "A project parent tracks a reserved or workspace path")))))

(defun %identity-environment (name email timestamp)
  (let ((date (format nil "@~D +0000" timestamp)))
    (list (cons "GIT_AUTHOR_NAME" name)
          (cons "GIT_AUTHOR_EMAIL" email)
          (cons "GIT_COMMITTER_NAME" name)
          (cons "GIT_COMMITTER_EMAIL" email)
          (cons "GIT_AUTHOR_DATE" date)
          (cons "GIT_COMMITTER_DATE" date))))

(defun %create-commit-object (tree-oid
                              first-parent
                              project-commits
                              message
                              directory
                              identity-name
                              identity-email
                              timestamp)
  (let ((arguments (list "commit-tree"
                         tree-oid
                         "-p"
                         first-parent)))
    (dolist (parent project-commits)
      (setf arguments
            (append arguments
                    (list "-p" parent))))
    (%successful-stdout
     (run-git arguments
              directory
              :input message
              :git-environment
              (%identity-environment identity-name
                                     identity-email
                                     timestamp))
     "creating the GAW commit object")))

(defun %update-source-ref (source-ref
                           old-oid
                           new-oid
                           directory
                           reflog-message)
  (let ((invocation
          (run-git (list "-c"
                         "core.hooksPath=/dev/null"
                         "-c"
                         "hook.gaw-reference-transaction.enabled=false"
                         "update-ref"
                         "-m"
                         reflog-message
                         source-ref
                         new-oid
                         old-oid)
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-commit-error :ref-moved
                            "The GAW branch changed before it could be updated"))
    new-oid))

(defun %prepare-commit (directory)
  (let* ((root (%ensure-worktree-root directory))
         (source-ref (%current-head-ref root)))
    (%ensure-no-operation-in-progress root)
    (%ensure-merged-index root)
    (let* ((first-parent
             (%resolve-first-parent source-ref
                                    root))
           (tree-oid (%write-tree root))
           (entries (%tree-entries tree-oid
                                   root)))
      (values root
              source-ref
              first-parent
              tree-oid
              entries))))

(defun %complete-commit (root
                         source-ref
                         first-parent
                         tree-oid
                         entries
                         workspace
                         message
                         project-revisions
                         allow-empty
                         reflog-message
                         identity-name
                         identity-email
                         timestamp)
  (let* ((project-commits
           (%resolve-project-commits project-revisions
                                     first-parent
                                     root)))
      (%call-with-workspace-error-as-commit-error
       (lambda () (validate-workspace workspace entries)))
      (%ensure-project-paths-disjoint workspace
                                      project-commits
                                      root)
      (when (and (null project-commits)
                 (not allow-empty)
                 (string= tree-oid
                          (%resolve-tree first-parent
                                         root)))
        (%signal-commit-error :empty-commit
                              "The staged GAW tree is unchanged"))
      (%update-source-ref
       source-ref
       first-parent
       (%create-commit-object tree-oid
                              first-parent
                              project-commits
                              message
                              root
                              identity-name
                              identity-email
                              timestamp)
       root
       reflog-message)))
