(in-package #:git-agent-workflow.state)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git read-config-at-tree read-tree-snapshot
                      validate-workspace find-project-path-conflict
                      %make-committed-state-finding
                      %make-committed-state-report))
    (unless (fboundp function)
      (error "Required state runtime dependency is unavailable: ~S"
             function))))

(defun %successful-state-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation
           (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %state-resolve-commit (source-ref directory)
  (let ((invocation
          (run-git (list "rev-parse" "--verify" "--end-of-options"
                         (concatenate 'string source-ref "^{commit}"))
                   directory)))
    (and (zerop (git-invocation-exit-status invocation))
         (git-invocation-stdout invocation))))

(defun %committed-state-marker-p (directory source-ref config-path)
  (let ((invocation
          (run-git (list "cat-file" "-e"
                         (format nil "~A:~A" source-ref config-path))
                   directory)))
    (case (git-invocation-exit-status invocation)
      (0 t)
      ((1 128) nil)
      (otherwise
       (error "Git failed while probing ~A on ~A: ~A"
              config-path source-ref
              (git-invocation-stderr invocation))))))

(defun %local-branches (directory source-ref-prefix)
  (let ((invocation
          (run-git (list "for-each-ref" "--format=%(refname)"
                         source-ref-prefix)
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Git failed while listing local branches: ~A"
             (git-invocation-stderr invocation)))
    (let ((output (git-invocation-stdout invocation)))
      (if (zerop (length output))
          '()
          (uiop:split-string output :separator '(#\Newline))))))

(defun %state-resolve-tree (commit-oid directory)
  (%successful-state-stdout
   (run-git (list "rev-parse" "--verify" "--end-of-options"
                  (concatenate 'string commit-oid "^{tree}"))
            directory)
   "resolving a GAW commit tree"))

(defun %state-commit-parents (commit-oid directory)
  (let* ((line (%successful-state-stdout
                (run-git (list "rev-list" "--parents" "-n" "1" commit-oid)
                         directory)
                "reading GAW commit parents"))
         (fields (uiop:split-string line :separator '(#\Space))))
    (unless (and fields (string= (first fields) commit-oid))
      (error "Git returned malformed parent output"))
    (rest fields)))

(defun %state-workspace-declarations (config)
  (mapcar (lambda (entry)
            (cons (workspace-entry-kind entry)
                  (workspace-entry-path entry)))
          (config-workspace config)))

(defun %validate-project-parent-tips (commit-oid workspace directory)
  (dolist (parent (rest (%state-commit-parents commit-oid directory)))
    (let* ((tree-oid (%state-resolve-tree parent directory))
           (entries (read-tree-snapshot directory tree-oid)))
      (when (find-project-path-conflict workspace entries)
        (return-from %validate-project-parent-tips
          (values nil
                  "An associated project parent tracks a reserved or workspace path")))))
  (values t "The associated project parent trees are disjoint"))

(defun %inspect-committed-state (directory source-ref config-path)
  (check-type directory pathname)
  (check-type source-ref string)
  (let ((findings '())
        (commit-oid nil)
        (tree-oid nil)
        (config nil)
        (workspace nil))
    (labels ((record (name status detail)
               (push (%make-committed-state-finding name status detail)
                     findings))
             (skip (name detail)
               (record name :skipped detail))
             (finish ()
               (%make-committed-state-report
                source-ref commit-oid tree-oid config workspace
                (nreverse findings))))
      (handler-case
          (setf commit-oid (%state-resolve-commit source-ref directory))
        (error (condition)
          (record :head :error
                  (format nil "Cannot resolve the GAW branch tip: ~A"
                          condition))))
      (cond
        ((null commit-oid)
         (unless (find :head findings
                       :key #'committed-state-finding-name)
           (record :head :error "The current GAW branch is unborn"))
         (dolist (name '(:head-config :head-workspace :project-parents))
           (skip name "Skipped because HEAD does not resolve to a commit"))
         (return-from %inspect-committed-state (finish)))
        (t
         (record :head :ok "HEAD resolves to a commit")))

      (handler-case
          (setf tree-oid (%state-resolve-tree commit-oid directory)
                config (read-config-at-tree directory tree-oid)
                workspace (%state-workspace-declarations config))
        (config-error (condition)
          (record :head-config :error
                  (format nil "Invalid HEAD config: ~A" condition)))
        (error (condition)
          (record :head-config :error
                  (format nil "Cannot inspect HEAD config: ~A" condition))))
      (unless config
        (skip :head-workspace "Skipped because HEAD config is unavailable")
        (skip :project-parents "Skipped because HEAD config is unavailable")
        (return-from %inspect-committed-state (finish)))
      (record :head-config :ok "HEAD contains a valid .gaw/config")

      (handler-case
          (progn
            (validate-workspace workspace
                                (read-tree-snapshot directory tree-oid))
            (record :head-workspace :ok
                    "HEAD satisfies its workspace declaration"))
        (workspace-error (condition)
          (record :head-workspace :error
                  (or (workspace-error-detail condition)
                      (format nil "~A" condition))))
        (error (condition)
          (record :head-workspace :error
                  (format nil "Cannot validate the HEAD workspace: ~A"
                          condition))))

      (handler-case
          (multiple-value-bind (ok detail)
              (%validate-project-parent-tips commit-oid workspace directory)
            (record :project-parents (if ok :ok :error) detail))
        (error (condition)
          (record :project-parents :error
                  (format nil "Cannot validate project parents: ~A"
                          condition))))
      (finish))))
