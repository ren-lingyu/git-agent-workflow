(in-package #:git-agent-workflow.branch)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git make-ref inspect-ref registered-ref-p current-ref
                      run-branch rename-ref-registration remove-ref-registration
                      restore-ref-registration worktree-root
                      current-local-head-ref inspect-committed-state
                      %signal-branch-error %make-branch-result))
    (unless (fboundp function)
      (error "Required branch runtime dependency is unavailable: ~S"
             function))))

(defun %branch-name (name directory source-ref-prefix)
  (check-type name string)
  (let ((invocation
          (run-git (list "check-ref-format" "--branch" name) directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-branch-error :invalid-name "Invalid branch name ~S" name)))
  (concatenate 'string source-ref-prefix name))

(defun %require-direct-source (source-ref directory)
  (let ((state (inspect-ref source-ref directory)))
    (unless (and (ref-state-exists-p state)
                 (not (ref-state-symbolic-p state)))
      (%signal-branch-error :missing-branch
                            "Local branch does not exist: ~S" source-ref))
    state))

(defun %require-valid-branch-state (source-ref directory)
  (unless (committed-state-report-ok-p
           (inspect-committed-state directory source-ref))
    (%signal-branch-error :invalid-state
                          "Branch is not valid GAW committed state: ~S"
                          source-ref)))

(defun %native-branch (arguments directory operation)
  (let ((invocation
          (run-branch arguments directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-branch-error :native-failure
                            "Git failed while ~A: ~A"
                            operation (git-invocation-stderr invocation)))))

(defun %try-native-rename-back (old-name directory)
  (let ((invocation
          (run-branch (list "-m" old-name) directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Native rename compensation failed: ~A"
             (git-invocation-stderr invocation)))))

(defun %rename-branch (directory new-name source-ref-prefix)
  (let* ((root (worktree-root directory))
         (old-source-ref (current-local-head-ref root))
         (selected-source-ref (current-ref root))
         (new-source-ref (%branch-name new-name root source-ref-prefix))
         (old-name (subseq old-source-ref (length source-ref-prefix))))
    (unless (string= old-source-ref selected-source-ref)
      (%signal-branch-error :not-current-gaw-branch
                            "The worktree branch is not refs/gaw/HEAD"))
    (%require-direct-source old-source-ref root)
    (%require-valid-branch-state old-source-ref root)
    (unless (registered-ref-p old-source-ref root)
      (%signal-branch-error :unregistered
                            "Branch is not registered: ~S" old-source-ref))
    (when (ref-state-exists-p (inspect-ref new-source-ref root))
      (%signal-branch-error :destination-exists
                            "Destination branch exists: ~S" new-source-ref))
    (when (ref-state-exists-p (inspect-ref (make-ref new-source-ref) root))
      (%signal-branch-error :destination-exists
                            "Destination registration exists: ~S"
                            (make-ref new-source-ref)))
    (%native-branch (list "-m" new-name) root "renaming the branch")
    (handler-case
        (rename-ref-registration old-source-ref new-source-ref root)
      (error (condition)
        (handler-case
            (%try-native-rename-back old-name root)
          (error (rollback)
            (%signal-branch-error
             :partial-failure
             "Protocol rename failed (~A); compensation failed: ~A"
             condition rollback)))
        (%signal-branch-error :protocol-failure
                              "Protocol rename failed and was compensated: ~A"
                              condition)))
    (handler-case
        (progn
          (unless (string= new-source-ref (current-local-head-ref root))
            (error "Worktree HEAD was not renamed"))
          (unless (string= new-source-ref (current-ref root))
            (error "refs/gaw/HEAD was not renamed"))
          (unless (registered-ref-p new-source-ref root)
            (error "New registration is missing"))
          (%require-valid-branch-state new-source-ref root))
      (error (condition)
        (let ((rollback-errors '()))
          (handler-case
              (rename-ref-registration new-source-ref old-source-ref root)
            (error (rollback) (push (princ-to-string rollback) rollback-errors)))
          (handler-case (%try-native-rename-back old-name root)
            (error (rollback) (push (princ-to-string rollback) rollback-errors)))
          (%signal-branch-error
           (if rollback-errors :partial-failure :verification-failure)
           "Rename verification failed (~A)~@[; compensation failed: ~{~A~^; ~}~]"
           condition (and rollback-errors (nreverse rollback-errors))))))
    (%make-branch-result :rename old-source-ref new-source-ref)))

(defun %restore-deleted-source (name object-id directory)
  (let ((invocation
          (run-branch (list name object-id) directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Cannot recreate deleted branch: ~A"
             (git-invocation-stderr invocation)))))

(defun %delete-branch (directory name source-ref-prefix)
  (let* ((source-ref (%branch-name name directory source-ref-prefix))
         (source-state (%require-direct-source source-ref directory))
         (object-id (ref-state-object-id source-state)))
    (%require-valid-branch-state source-ref directory)
    (handler-case
        (unless (registered-ref-p source-ref directory)
          (%signal-branch-error :unregistered
                                "Branch is not registered: ~S" source-ref))
      (branch-error (condition) (error condition))
      (error (condition)
        (%signal-branch-error :invalid-registration "~A" condition)))
    (%native-branch (list "-d" name) directory "deleting the branch")
    (handler-case
        (remove-ref-registration source-ref directory)
      (error (condition)
        (handler-case
            (%restore-deleted-source name object-id directory)
          (error (rollback)
            (%signal-branch-error
             :partial-failure
             "Protocol deletion failed (~A); branch recreation failed: ~A"
             condition rollback)))
        (%signal-branch-error
         :partial-failure
         "Protocol deletion failed (~A); the branch ref was recreated, but native deletion metadata may have changed"
         condition)))
    (%make-branch-result :delete source-ref nil)))
