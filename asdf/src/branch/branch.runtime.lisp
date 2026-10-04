(in-package #:git-agent-workflow.branch)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git inspect-ref current-ref
                      run-branch rename-selected-source worktree-root
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
    (when (ref-state-exists-p (inspect-ref new-source-ref root))
      (%signal-branch-error :destination-exists
                            "Destination branch exists: ~S" new-source-ref))
    (%native-branch (list "-m" new-name) root "renaming the branch")
    (handler-case
        (rename-selected-source old-source-ref new-source-ref root)
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
          (%require-valid-branch-state new-source-ref root))
      (error (condition)
        (let ((rollback-errors '()))
          (handler-case
              (rename-selected-source new-source-ref old-source-ref root)
            (error (rollback) (push (princ-to-string rollback) rollback-errors)))
          (handler-case (%try-native-rename-back old-name root)
            (error (rollback) (push (princ-to-string rollback) rollback-errors)))
          (%signal-branch-error
           (if rollback-errors :partial-failure :verification-failure)
           "Rename verification failed (~A)~@[; compensation failed: ~{~A~^; ~}~]"
           condition (and rollback-errors (nreverse rollback-errors))))))
    (%make-branch-result :rename old-source-ref new-source-ref)))

(defun %delete-branch (directory name source-ref-prefix selector-ref force)
  (let* ((source-ref (%branch-name name directory source-ref-prefix))
         (selector-state (inspect-ref selector-ref directory)))
    (%require-direct-source source-ref directory)
    (%require-valid-branch-state source-ref directory)
    (when (ref-state-exists-p selector-state)
      (let ((selected
              (handler-case (current-ref directory)
                (error (condition)
                  (%signal-branch-error :invalid-selector "~A" condition)))))
        (%require-valid-branch-state selected directory)
        (when (string= source-ref selected)
          (%signal-branch-error :selected-branch
                                "Run git gaw undeploy or select another branch with git gaw deploy --branch before deletion"))))
    (%native-branch (list (if force "-D" "-d") name)
                    directory "deleting the branch")
    (%make-branch-result :delete source-ref nil)))
