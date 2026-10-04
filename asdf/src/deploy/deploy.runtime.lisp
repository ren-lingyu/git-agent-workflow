(in-package #:git-agent-workflow.deploy)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git inspect-ref current-ref
                      protocol-refs select-source-ref run-worktree
                      restore-source-selection inspect-committed-state
                      committed-state-marker-p local-branches
                      inspect-protection-hook ensure-protection-hook check
                      %signal-deploy-error %make-deploy-result
                      list-worktrees))
    (unless (fboundp function)
      (error "Required deploy runtime dependency is unavailable: ~S"
             function))))

(defun %deploy-git-output (arguments directory operation)
  (let ((invocation (run-git arguments directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-deploy-error
       :git-failure "Git failed while ~A: ~A"
       operation (git-invocation-stderr invocation)))
    (git-invocation-stdout invocation)))

(defun %validate-branch-name (branch directory source-ref-prefix)
  (check-type branch string)
  (when (zerop (length branch))
    (%signal-deploy-error :invalid-branch "Branch name is empty"))
  (let ((invocation
          (run-git (list "check-ref-format" "--branch" branch) directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-deploy-error :invalid-branch
                            "Invalid local branch name ~S" branch)))
  (concatenate 'string source-ref-prefix branch))

(defun %state-error-detail (report)
  (let ((finding
          (find :error (committed-state-report-findings report)
                :key #'committed-state-finding-status)))
    (if finding
        (committed-state-finding-detail finding)
        "The committed state is invalid")))

(defun %require-valid-state (directory source-ref)
  (let ((report (inspect-committed-state directory source-ref)))
    (unless (committed-state-report-ok-p report)
      (%signal-deploy-error :invalid-committed-state
                            "Branch ~S is not valid GAW history: ~A"
                            source-ref (%state-error-detail report)))
    report))

(defun %require-clean-protocol-namespace (directory head-ref
                                           legacy-ref-prefix source-ref-prefix)
  (let* ((head (inspect-ref head-ref directory))
         (candidates
           (remove-duplicates
            (append (protocol-refs directory)
                    (when (and (ref-state-exists-p head)
                               (ref-state-symbolic-p head)
                               (uiop:string-prefix-p
                                legacy-ref-prefix
                                (ref-state-symbolic-target head)))
                      (list (ref-state-symbolic-target head)))
                    (loop for source in (local-branches directory)
                          collect (concatenate
                                   'string legacy-ref-prefix
                                   (subseq source (length source-ref-prefix)))))
            :test #'string=)))
    (dolist (ref candidates)
      (unless (string= ref head-ref)
        (when (ref-state-exists-p (inspect-ref ref directory))
          (%signal-deploy-error
           :corrupt-metadata
           "Unexpected or legacy GAW protocol ref ~S; run git gaw undeploy"
           ref))))))

(defun %discover-source-ref (directory head-ref)
  (let ((head-state (inspect-ref head-ref directory))
        (warnings '()))
    (when (ref-state-exists-p head-state)
      (handler-case
          (let ((source-ref (current-ref directory)))
            (%require-valid-state directory source-ref)
            (return-from %discover-source-ref
              (values source-ref warnings)))
        (error (condition)
          (%signal-deploy-error :corrupt-metadata
                                "Invalid refs/gaw/HEAD state: ~A"
                                condition))))
    (let ((candidates '()))
      (dolist (source-ref (local-branches directory))
        (when (committed-state-marker-p directory source-ref)
          (let ((report (inspect-committed-state directory source-ref)))
            (if (committed-state-report-ok-p report)
                (push source-ref candidates)
                (push (format nil
                              "Ignoring GAW-like branch ~A: ~A"
                              source-ref (%state-error-detail report))
                      warnings)))))
      (setf candidates (nreverse candidates))
      (case (length candidates)
        (0 (%signal-deploy-error :no-candidate
                                 "No valid local GAW branch was found"))
        (1 (values (first candidates) (nreverse warnings)))
        (otherwise
         (%signal-deploy-error
          :ambiguous-branch
          "Multiple valid local GAW branches were found; use --branch"))))))

(defun %path-key (path)
  (string-right-trim '(#\/)
                     (uiop:native-namestring
                      (uiop:ensure-directory-pathname path))))

(defun %resolve-worktree-plan (directory source-ref requested-path)
  (let* ((records (list-worktrees directory))
         (attached
           (remove-if-not
            (lambda (record)
              (and (string= source-ref
                            (or (worktree-record-branch record) ""))
                   (not (worktree-record-detached-p record))
                   (not (worktree-record-prunable-p record))))
            records)))
    (if requested-path
        (let* ((absolute
                 (uiop:ensure-directory-pathname
                  (merge-pathnames (pathname requested-path) directory)))
               (key (%path-key absolute))
               (at-path
                 (find key records :test #'string=
                       :key (lambda (record)
                              (%path-key (worktree-record-path record))))))
          (cond
            (at-path
             (unless (and (string= source-ref
                                   (or (worktree-record-branch at-path) ""))
                          (not (worktree-record-detached-p at-path))
                          (not (worktree-record-prunable-p at-path)))
               (%signal-deploy-error
                :worktree-conflict
                "Worktree path ~A is attached to different or invalid state"
                absolute))
             (values :existing-worktree absolute))
            (attached
             (%signal-deploy-error
              :worktree-conflict
              "Branch ~A is already attached at ~A"
              source-ref (worktree-record-path (first attached))))
            ((probe-file absolute)
             (%signal-deploy-error :worktree-conflict
                                   "Worktree path already exists: ~A" absolute))
            (t (values :created-worktree absolute))))
        (case (length attached)
          (0 (values :repository-only nil))
          (1 (values :existing-worktree
                     (uiop:ensure-directory-pathname
                      (worktree-record-path (first attached)))))
          (otherwise
           (%signal-deploy-error
            :worktree-conflict
            "Branch ~A is attached to multiple worktrees" source-ref))))))

(defun %preflight-hook (directory)
  (let ((configuration (inspect-protection-hook directory)))
    (when (eq :conflict (hook-configuration-status configuration))
      (%signal-deploy-error :hook-conflict "~A"
                            (hook-configuration-detail configuration)))))

(defun %create-worktree (directory path source-ref source-ref-prefix)
  (let* ((branch (subseq source-ref (length source-ref-prefix)))
         (invocation
           (run-worktree (list "add" "--quiet"
                               (uiop:native-namestring path) branch)
                         directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-deploy-error :worktree-create-failed
                            "Cannot create worktree ~A: ~A"
                            path (git-invocation-stderr invocation)))))

(defun %remove-worktree (directory path)
  (let ((invocation
          (run-worktree (list "remove" (uiop:native-namestring path))
                        directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Cannot remove worktree ~A: ~A"
             path (git-invocation-stderr invocation)))))

(defun %deploy (directory branch requested-path source-ref-prefix
                legacy-ref-prefix head-ref)
  (check-type directory pathname)
  (%deploy-git-output '("rev-parse" "--git-dir") directory
                      "locating the repository")
  (%preflight-hook directory)
  (%require-clean-protocol-namespace directory head-ref
                                      legacy-ref-prefix source-ref-prefix)
  (multiple-value-bind (source-ref warnings)
      (if branch
          (let ((source-ref
                  (%validate-branch-name branch directory source-ref-prefix)))
            (let ((head-state (inspect-ref head-ref directory)))
              (when (ref-state-exists-p head-state)
                (handler-case (%require-valid-state
                               directory (current-ref directory))
                  (error (condition)
                    (%signal-deploy-error
                     :corrupt-metadata "Invalid refs/gaw/HEAD state: ~A"
                     condition)))))
            (%require-valid-state directory source-ref)
            (values source-ref nil))
          (%discover-source-ref directory head-ref))
    (multiple-value-bind (mode worktree-path)
        (%resolve-worktree-plan directory source-ref requested-path)
      (let ((selection nil)
            (created nil))
        (handler-case
            (progn
              (setf selection (select-source-ref source-ref directory))
              (when (eq mode :created-worktree)
                (%create-worktree directory worktree-path source-ref
                                  source-ref-prefix)
                (setf created t))
              (when worktree-path
                (unless (check-report-ok-p (check worktree-path))
                  (%signal-deploy-error :invalid-worktree
                                        "The deployed worktree failed git gaw check")))
              (ensure-protection-hook directory)
              (%make-deploy-result
               source-ref
               (subseq source-ref (length source-ref-prefix))
               mode worktree-path warnings))
          (error (condition)
            (let ((rollback-errors '()))
              (when created
                (handler-case (%remove-worktree directory worktree-path)
                  (error (rollback)
                    (push (princ-to-string rollback) rollback-errors))))
              (when selection
                (handler-case (restore-source-selection selection directory)
                  (error (rollback)
                    (push (princ-to-string rollback) rollback-errors))))
              (if rollback-errors
                  (%signal-deploy-error
                   :partial-failure "~A; compensation failed: ~{~A~^; ~}"
                   condition (nreverse rollback-errors))
                  (if (typep condition 'deploy-error)
                      (error condition)
                      (%signal-deploy-error :failure "~A" condition))))))))))
