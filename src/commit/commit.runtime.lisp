(in-package #:git-agent-workflow.commit)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      run-git-bytes
                      %signal-commit-error
                      %parse-tree-entries
                      %validate-workspace-tree
                      %find-project-path-conflict))
    (unless (fboundp function)
      (error "Required commit runtime dependency is unavailable: ~S"
             function))))

(defun %successful-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation
           (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %successful-octets (invocation operation)
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
  (let* ((invocation
           (run-git '("rev-parse" "--show-toplevel")
                    directory))
         (root
           (if (zerop (git-invocation-exit-status invocation))
               (git-invocation-stdout invocation)
               (%signal-commit-error :not-worktree-root
                                     "The directory is not a Git worktree")))
         (root-path
           (uiop:ensure-directory-pathname
            (truename root))))
    (unless (equal (namestring (%canonical-directory directory))
                   (namestring root-path))
      (%signal-commit-error :not-worktree-root
                            "git gaw commit must run at the worktree root"))
    root-path))

(defun %current-head-ref (directory source-ref-prefix)
  (let ((invocation
          (run-git '("symbolic-ref" "--quiet" "HEAD")
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-commit-error :detached-head
                            "The worktree HEAD is detached or unborn"))
    (let ((head-ref (git-invocation-stdout invocation)))
      (unless (and (> (length head-ref)
                      (length source-ref-prefix))
                   (string= source-ref-prefix
                            head-ref
                            :end2 (length source-ref-prefix)))
        (%signal-commit-error :detached-head
                              "The worktree HEAD is not a local branch"))
      head-ref)))

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

(defun %git-path (name directory)
  (%successful-stdout
   (run-git (list "rev-parse"
                  "--path-format=absolute"
                  "--git-path"
                  name)
            directory)
   "locating Git operation state"))

(defun %ensure-no-operation-in-progress (directory operation-state-paths)
  (dolist (path operation-state-paths)
    (when (probe-file (%git-path path directory))
      (%signal-commit-error :operation-in-progress
                            "Git operation state is present: ~A"
                            path))))

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
  (%parse-tree-entries
   (%successful-octets
    (run-git-bytes (list "ls-tree"
                         "-r"
                         "-t"
                         "-z"
                         "--full-tree"
                         tree-oid)
                   directory)
    "reading a Git tree")))

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
                                       directory
                                       protocol-root
                                       tree-mode
                                       tree-type)
  (dolist (commit-oid project-commits)
    (let* ((tree-oid (%resolve-tree commit-oid
                                    directory))
           (conflict
             (%find-project-path-conflict
              workspace
              (%tree-entries tree-oid directory)
              protocol-root
              tree-mode
              tree-type)))
      (when conflict
        (%signal-commit-error :path-conflict
                              "A project parent tracks a reserved or workspace path")))))

(defun %configured-identity-value (key directory)
  (let ((invocation
          (run-git (list "config" "--get" key)
                   directory)))
    (cond
      ((zerop (git-invocation-exit-status invocation))
       (let ((value (git-invocation-stdout invocation)))
         (if (plusp (length value))
             value
             (%signal-commit-error :missing-identity
                                   "Git config ~A is empty"
                                   key))))
      ((= (git-invocation-exit-status invocation) 1)
       (%signal-commit-error :missing-identity
                             "Git config ~A is missing"
                             key))
      (t
       (error "Git failed while reading ~A: ~A"
              key
              (git-invocation-stderr invocation))))))

(defun %identity-environment (directory timestamp)
  (let ((name (%configured-identity-value "user.name"
                                           directory))
        (email (%configured-identity-value "user.email"
                                            directory))
        (date (format nil
                      "@~D +0000"
                      timestamp)))
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
              (%identity-environment directory
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

(defun %prepare-commit (directory
                        source-ref-prefix
                        operation-state-paths)
  (let* ((root (%ensure-worktree-root directory))
         (source-ref (%current-head-ref root
                                       source-ref-prefix)))
    (%ensure-no-operation-in-progress root
                                      operation-state-paths)
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
                         protocol-root
                         file-modes
                         tree-mode
                         gitlink-mode
                         blob-type
                         tree-type
                         reflog-message
                         timestamp)
  (let* ((protocol-octets
           (string-to-octets protocol-root
                             :encoding :utf-8))
         (project-commits
           (%resolve-project-commits project-revisions
                                     first-parent
                                     root)))
      (%validate-workspace-tree workspace
                                entries
                                protocol-octets
                                file-modes
                                tree-mode
                                gitlink-mode
                                blob-type
                                tree-type)
      (%ensure-project-paths-disjoint workspace
                                      project-commits
                                      root
                                      protocol-octets
                                      tree-mode
                                      tree-type)
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
                              timestamp)
       root
       reflog-message)))
