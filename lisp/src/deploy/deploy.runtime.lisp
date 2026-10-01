(in-package #:git-agent-workflow.deploy)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git inspect-ref current-ref registered-ref-p
                      registration-refs protocol-refs select-ref
                      restore-selection inspect-committed-state
                      committed-state-marker-p local-branches
                      inspect-protection-hook ensure-protection-hook check
                      %signal-deploy-error %make-deploy-result
                      %make-worktree-record))
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

(defun %source-from-registration (registration-ref
                                  target-ref-prefix source-ref-prefix)
  (unless (and (> (length registration-ref) (length target-ref-prefix))
               (string= target-ref-prefix registration-ref
                        :end2 (length target-ref-prefix)))
    (%signal-deploy-error :corrupt-metadata
                          "Invalid registration ref ~S" registration-ref))
  (concatenate 'string source-ref-prefix
               (subseq registration-ref (length target-ref-prefix))))

(defun %validate-registrations (directory target-ref-prefix source-ref-prefix)
  (dolist (registration-ref (registration-refs directory))
    (let ((source-ref
            (%source-from-registration registration-ref
                                       target-ref-prefix source-ref-prefix)))
      (handler-case
          (progn
            (unless (registered-ref-p source-ref directory)
              (%signal-deploy-error :corrupt-metadata
                                    "Registration disappeared: ~S"
                                    registration-ref))
            (%require-valid-state directory source-ref))
        (deploy-error (condition) (error condition))
        (error (condition)
          (%signal-deploy-error :corrupt-metadata
                                "Invalid registration ~S: ~A"
                                registration-ref condition))))))

(defun %unknown-protocol-warnings (directory head-ref target-ref-prefix)
  (loop for ref in (protocol-refs directory)
        unless (or (string= ref head-ref)
                   (and (> (length ref) (length target-ref-prefix))
                        (string= target-ref-prefix ref
                                 :end2 (length target-ref-prefix))))
          collect (format nil "Preserving unknown GAW protocol ref ~A" ref)))

(defun %discover-source-ref (directory source-ref-prefix
                             target-ref-prefix head-ref)
  (let ((head-state (inspect-ref head-ref directory))
        (warnings (%unknown-protocol-warnings
                   directory head-ref target-ref-prefix)))
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
    (%validate-registrations directory target-ref-prefix source-ref-prefix)
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

(defun %split-nul-fields (string)
  (let ((fields '()) (start 0))
    (loop for position = (position #\Null string :start start)
          do (push (subseq string start position) fields)
          if position do (setf start (1+ position)) else do (return))
    (nreverse fields)))

(defun %parse-worktrees (output)
  (let ((records '())
        (path nil) (branch nil) (detached nil) (prunable nil))
    (labels ((finish ()
               (when path
                 (push (%make-worktree-record path branch detached prunable)
                       records))
               (setf path nil branch nil detached nil prunable nil)))
      (dolist (field (%split-nul-fields output))
        (cond
          ((zerop (length field)) (finish))
          ((uiop:string-prefix-p "worktree " field)
           (finish)
           (setf path (subseq field 9)))
          ((uiop:string-prefix-p "branch " field)
           (setf branch (subseq field 7)))
          ((string= field "detached") (setf detached t))
          ((uiop:string-prefix-p "prunable" field) (setf prunable t))))
      (finish))
    (nreverse records)))

(defun %worktrees (directory)
  (%parse-worktrees
   (%deploy-git-output '("worktree" "list" "--porcelain" "-z")
                       directory "listing worktrees")))

(defun %path-key (path)
  (string-right-trim '(#\/)
                     (uiop:native-namestring
                      (uiop:ensure-directory-pathname path))))

(defun %resolve-worktree-plan (directory source-ref requested-path)
  (let* ((records (%worktrees directory))
         (attached
           (remove-if-not
            (lambda (record)
              (and (string= source-ref
                            (or (%worktree-record-branch record) ""))
                   (not (%worktree-record-detached-p record))
                   (not (%worktree-record-prunable-p record))))
            records)))
    (if requested-path
        (let* ((absolute
                 (uiop:ensure-directory-pathname
                  (merge-pathnames (pathname requested-path) directory)))
               (key (%path-key absolute))
               (at-path
                 (find key records :test #'string=
                       :key (lambda (record)
                              (%path-key (%worktree-record-path record))))))
          (cond
            (at-path
             (unless (and (string= source-ref
                                   (or (%worktree-record-branch at-path) ""))
                          (not (%worktree-record-detached-p at-path))
                          (not (%worktree-record-prunable-p at-path)))
               (%signal-deploy-error
                :worktree-conflict
                "Worktree path ~A is attached to different or invalid state"
                absolute))
             (values :existing-worktree absolute))
            (attached
             (%signal-deploy-error
              :worktree-conflict
              "Branch ~A is already attached at ~A"
              source-ref (%worktree-record-path (first attached))))
            ((probe-file absolute)
             (%signal-deploy-error :worktree-conflict
                                   "Worktree path already exists: ~A" absolute))
            (t (values :created-worktree absolute))))
        (case (length attached)
          (0 (values :repository-only nil))
          (1 (values :existing-worktree
                     (uiop:ensure-directory-pathname
                      (%worktree-record-path (first attached)))))
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
           (run-git (list "-c"
                          "hook.gaw-reference-transaction.enabled=false"
                          "worktree" "add" "--quiet"
                          (uiop:native-namestring path) branch)
                    directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-deploy-error :worktree-create-failed
                            "Cannot create worktree ~A: ~A"
                            path (git-invocation-stderr invocation)))))

(defun %remove-worktree (directory path)
  (let ((invocation
          (run-git (list "-c"
                         "hook.gaw-reference-transaction.enabled=false"
                         "worktree" "remove"
                         (uiop:native-namestring path))
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Cannot remove worktree ~A: ~A"
             path (git-invocation-stderr invocation)))))

(defun %deploy (directory branch requested-path source-ref-prefix
                target-ref-prefix head-ref)
  (check-type directory pathname)
  (%deploy-git-output '("rev-parse" "--git-dir") directory
                      "locating the repository")
  (%preflight-hook directory)
  (multiple-value-bind (source-ref warnings)
      (if branch
          (let ((source-ref
                  (%validate-branch-name branch directory source-ref-prefix)))
            (%validate-registrations directory
                                     target-ref-prefix source-ref-prefix)
            (let ((head-state (inspect-ref head-ref directory)))
              (when (ref-state-exists-p head-state)
                (handler-case (current-ref directory)
                  (error (condition)
                    (%signal-deploy-error
                     :corrupt-metadata "Invalid refs/gaw/HEAD state: ~A"
                     condition)))))
            (%require-valid-state directory source-ref)
            (handler-case (registered-ref-p source-ref directory)
              (error (condition)
                (%signal-deploy-error :corrupt-metadata "~A" condition)))
            (values source-ref
                    (%unknown-protocol-warnings
                     directory head-ref target-ref-prefix)))
          (%discover-source-ref directory source-ref-prefix
                                target-ref-prefix head-ref))
    (multiple-value-bind (mode worktree-path)
        (%resolve-worktree-plan directory source-ref requested-path)
      (let ((selection nil)
            (created nil))
        (handler-case
            (progn
              (setf selection (select-ref source-ref directory))
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
                (handler-case (restore-selection selection directory)
                  (error (rollback)
                    (push (princ-to-string rollback) rollback-errors))))
              (if rollback-errors
                  (%signal-deploy-error
                   :partial-failure "~A; compensation failed: ~{~A~^; ~}"
                   condition (nreverse rollback-errors))
                  (if (typep condition 'deploy-error)
                      (error condition)
                      (%signal-deploy-error :failure "~A" condition))))))))))
