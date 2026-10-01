(in-package #:git-agent-workflow/tests.commit)

(defun %repository-git (directory &rest arguments)
  (call-git (append (list "-C"
                          (namestring directory))
                    arguments)))

(defun %message (text)
  (string-to-octets text
                    :encoding :utf-8))

(defun %write-text (directory name text)
  (write-test-octets (merge-pathnames name directory)
                     (%message text)))

(defun %commit-failure-reason (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (commit-error (condition)
      (commit-error-reason condition))))

(defun %assert-commit-error (reason thunk)
  (assert (eq reason
              (%commit-failure-reason thunk))))

(defun %initialize-gaw-branch (directory)
  (%repository-git directory
                   "config"
                   "--local"
                   "user.name"
                   "GAW Test")
  (%repository-git directory
                   "config"
                   "--local"
                   "user.email"
                   "gaw-test@example.invalid")
  (%write-text directory
               ".gaw/config"
               "(:workspace ((:file \"AGENTS.md\") (:directory \"notes\")))")
  (%write-text directory
               "AGENTS.md"
               "initial")
  (%repository-git directory
                   "add"
                   "--"
                   ".gaw/config"
                   "AGENTS.md")
  (let* ((tree (%repository-git directory
                                "write-tree"))
         (commit (%repository-git directory
                                  "commit-tree"
                                  tree
                                  "-m"
                                  "initial GAW state")))
    (%repository-git directory
                     "update-ref"
                     "refs/heads/gaw"
                     commit)
    (%repository-git directory
                     "symbolic-ref"
                     "HEAD"
                     "refs/heads/gaw")
    (%repository-git directory
                     "symbolic-ref"
                     "refs/gaw/heads/gaw"
                     "refs/heads/gaw")
    commit))

(defun %with-gaw-repository (function)
  (with-test-repository (directory)
    (let ((initial (%initialize-gaw-branch directory)))
      (funcall function directory initial))))

(defun %create-project-commit (directory paths message)
  (let ((gaw-tree (%repository-git directory
                                   "write-tree")))
    (unwind-protect
         (progn
           (%repository-git directory
                            "read-tree"
                            "--empty")
           (dolist (path paths)
             (%write-text directory
                          path
                          path)
             (%repository-git directory
                              "add"
                              "--"
                              path))
           (let ((tree (%repository-git directory
                                        "write-tree")))
             (%repository-git directory
                              "commit-tree"
                              tree
                              "-m"
                              message)))
      (%repository-git directory
                       "read-tree"
                       gaw-tree))))

(defun %commit-parents (directory commit-oid)
  (rest (uiop:split-string
         (%repository-git directory
                          "rev-list"
                          "--parents"
                          "-n"
                          "1"
                          commit-oid)
         :separator '(#\Space))))

(defun %commit-message-octets (directory commit-oid)
  (let* ((octets
           (git-invocation-stdout
            (run-git-bytes (list "cat-file"
                                 "commit"
                                 commit-oid)
                           directory)))
         (separator
           (loop for index below (1- (length octets))
                 when (and (= (aref octets index) 10)
                           (= (aref octets (1+ index)) 10))
                   do (return index))))
    (assert separator)
    (subseq octets
            (+ separator 2))))

(defun %test-ordinary-commit-uses-index-tree ()
  (%with-gaw-repository
   (lambda (directory initial)
     (%write-text directory
                  "AGENTS.md"
                  "staged")
     (%repository-git directory
                      "add"
                      "--"
                      "AGENTS.md")
     (%write-text directory
                  "AGENTS.md"
                  "unstaged")
     (%write-text directory
                  "untracked"
                  "ignored")
     (let* ((expected-tree (%repository-git directory
                                            "write-tree"))
            (new (commit directory
                         (%message "ordinary"))))
       (assert (string= new
                        (%repository-git directory
                                         "rev-parse"
                                         "refs/heads/gaw")))
       (assert (equal (list initial)
                      (%commit-parents directory new)))
       (assert (string= expected-tree
                        (%repository-git directory
                                         "rev-parse"
                                         (concatenate 'string
                                                      new
                                                      "^{tree}"))))))))

(defun %test-associated-commit-preserves-parent-order ()
  (%with-gaw-repository
   (lambda (directory initial)
     (let ((first (%create-project-commit directory
                                          '("src/one")
                                          "one"))
           (second (%create-project-commit directory
                                           '("src/two")
                                           "two")))
       (let ((new (commit directory
                          (%message "associated")
                          :project-commits
                          (list first second))))
         (assert (equal (list initial first second)
                        (%commit-parents directory new))))))))

(defun %test-associated-commit-rejects-conflicts ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (let ((project (%create-project-commit directory
                                            '("AGENTS.md")
                                            "conflict")))
       (%assert-commit-error
        :path-conflict
        (lambda ()
          (commit directory
                  (%message "conflict")
                  :project-commits (list project))))))))

(defun %test-associated-commit-rejects-duplicate-parent ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (let ((project (%create-project-commit directory
                                            '("src/project")
                                            "project")))
       (%assert-commit-error
        :duplicate-parent
        (lambda ()
          (commit directory
                  (%message "duplicate")
                  :project-commits (list project project))))))))

(defun %test-commit-enforces-empty-policies ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%assert-commit-error
      :empty-commit
      (lambda ()
        (commit directory
                (%message "empty"))))
     (assert (stringp
              (commit directory
                      (%message "allowed")
                      :allow-empty t)))
     (%assert-commit-error
      :empty-message
      (lambda ()
        (commit directory
                (make-array 0
                            :element-type '(unsigned-byte 8))
                :allow-empty t)))
     (assert (stringp
              (commit directory
                      (make-array 0
                                  :element-type '(unsigned-byte 8))
                      :allow-empty t
                      :allow-empty-message t))))))

(defun %test-commit-preserves-message-bytes ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (let* ((message
              (make-array 3
                          :element-type '(unsigned-byte 8)
                          :initial-contents '(65 1 10)))
            (new (commit directory
                         message
                         :allow-empty t)))
       (assert (equalp message
                       (%commit-message-octets directory new)))))))

(defun %test-commit-controls-identity-time-and-signing ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%repository-git directory
                      "config"
                      "--local"
                      "user.name"
                      "Hostile User")
     (%repository-git directory
                      "config"
                      "--local"
                      "user.email"
                      "hostile@example.invalid")
     (%repository-git directory
                      "config"
                      "--local"
                      "commit.gpgSign"
                      "true")
     (let* ((new (commit directory
                         (%message "metadata")
                         :allow-empty t))
            (raw (%repository-git directory
                                  "cat-file"
                                  "commit"
                                  new)))
       (assert (search "author Git Agent Workflow <gaw@invalid>"
                       raw))
       (assert (search "committer Git Agent Workflow <gaw@invalid>"
                       raw))
       (assert (search " +0000"
                       raw))
       (assert (not (search "gpgsig "
                            raw)))))))

(defun %test-commit-does-not-require-configured-identity ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%repository-git directory
                      "config"
                      "--local"
                      "--unset-all"
                      "user.name")
     (%repository-git directory
                      "config"
                      "--local"
                      "--unset-all"
                      "user.email")
     (let* ((new (commit directory
                         (%message "built-in identity")
                         :allow-empty t))
            (raw (%repository-git directory
                                  "cat-file"
                                  "commit"
                                  new)))
       (assert (search "author Git Agent Workflow <gaw@invalid>"
                       raw))
       (assert (search "committer Git Agent Workflow <gaw@invalid>"
                       raw))))))

(defun %test-commit-rejects-invalid-worktree-and-tree ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (let ((nested (merge-pathnames "nested/"
                                    directory)))
       (ensure-directories-exist
        (merge-pathnames "placeholder"
                         nested))
       (%assert-commit-error
        :not-worktree-root
        (lambda ()
          (commit nested
                  (%message "nested")
                  :allow-empty t))))
     (%write-text directory
                  "outside"
                  "outside")
     (%repository-git directory
                      "add"
                      "--"
                      "outside")
     (%assert-commit-error
      :invalid-workspace
      (lambda ()
        (commit directory
                (%message "outside")))))))

(defun %test-commit-rejects-gitlink-inside-workspace-directory ()
  (%with-gaw-repository
   (lambda (directory initial)
     (%repository-git directory
                      "update-index"
                      "--add"
                      "--cacheinfo"
                      "160000"
                      initial
                      "notes/submodule")
     (%assert-commit-error
      :invalid-workspace
      (lambda ()
        (commit directory
                (%message "gitlink")))))))

(defun %test-commit-ignores-shared-gaw-head ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%repository-git directory
                      "symbolic-ref"
                      "refs/gaw/HEAD"
                      "refs/gaw/heads/other")
     (assert (stringp
              (commit directory
                      (%message "worktree head")
                      :allow-empty t))))))

(defun %test-commit-requires-registration ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%repository-git directory
                      "symbolic-ref"
                      "--delete"
                      "refs/gaw/heads/gaw")
     (%assert-commit-error
      :unregistered-branch
      (lambda ()
        (commit directory
                (%message "unregistered")
                :allow-empty t))))))

(defun %test-commit-rejects-operation-state ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (write-test-octets
      (merge-pathnames ".git/MERGE_HEAD"
                       directory)
      (%message "state"))
     (%assert-commit-error
      :operation-in-progress
      (lambda ()
        (commit directory
                (%message "operation")
                :allow-empty t))))))

(defun %test-commit-disables-only-gaw-configured-hook ()
  (%with-gaw-repository
   (lambda (directory initial)
     (declare (ignore initial))
     (%repository-git directory
                      "config"
                      "--local"
                      "hook.gaw-reference-transaction.event"
                      "reference-transaction")
     (%repository-git directory
                      "config"
                      "--local"
                      "hook.gaw-reference-transaction.command"
                      "false")
     (%repository-git directory
                      "config"
                      "--local"
                      "hook.gaw-test-observer.event"
                      "reference-transaction")
     (%repository-git directory
                      "config"
                      "--local"
                      "hook.gaw-test-observer.command"
                      "touch configured-hook-ran")
     (assert (stringp
              (commit directory
                      (%message "configured hooks")
                      :allow-empty t)))
     (assert (probe-file
              (merge-pathnames "configured-hook-ran"
                               directory))))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.commit)))
    (dolist (name '("COMMIT"
                    "COMMIT-ERROR"
                    "COMMIT-ERROR-REASON"))
      (multiple-value-bind (symbol status)
          (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun %run-commit-tests ()
  (%test-ordinary-commit-uses-index-tree)
  (%test-associated-commit-preserves-parent-order)
  (%test-associated-commit-rejects-conflicts)
  (%test-associated-commit-rejects-duplicate-parent)
  (%test-commit-enforces-empty-policies)
  (%test-commit-preserves-message-bytes)
  (%test-commit-controls-identity-time-and-signing)
  (%test-commit-does-not-require-configured-identity)
  (%test-commit-rejects-invalid-worktree-and-tree)
  (%test-commit-rejects-gitlink-inside-workspace-directory)
  (%test-commit-ignores-shared-gaw-head)
  (%test-commit-requires-registration)
  (%test-commit-rejects-operation-state)
  (%test-commit-disables-only-gaw-configured-hook)
  (%test-public-package-boundary)
  (format t
          "~&All commit tests passed.~%")
  t)
