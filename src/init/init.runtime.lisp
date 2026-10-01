(in-package #:git-agent-workflow.init)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git inspect-ref protocol-refs initialize-ref-graph
                      remove-initial-ref-graph local-branches
                      committed-state-marker-p inspect-committed-state
                      inspect-protection-hook deploy %signal-init-error
                      %make-init-result))
    (unless (fboundp function)
      (error "Required init runtime dependency is unavailable: ~S"
             function))))

(defun %init-git-output (arguments directory operation &key input)
  (let ((invocation (run-git arguments directory :input input)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-init-error :git-failure "Git failed while ~A: ~A"
                          operation (git-invocation-stderr invocation)))
    (git-invocation-stdout invocation)))

(defun %init-source-ref (branch directory source-ref-prefix)
  (check-type branch string)
  (let ((invocation
          (run-git (list "check-ref-format" "--branch" branch) directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-init-error :invalid-branch
                          "Invalid local branch name ~S" branch)))
  (concatenate 'string source-ref-prefix branch))

(defun %preflight-init-history (directory)
  (dolist (source-ref (local-branches directory))
    (when (committed-state-marker-p directory source-ref)
      (if (committed-state-report-ok-p
           (inspect-committed-state directory source-ref))
          (%signal-init-error
           :already-initialized
           "Existing branch ~S already contains valid GAW history" source-ref)
          (%signal-init-error
           :ambiguous-history
           "Existing branch ~S contains an invalid GAW marker" source-ref)))))

(defun %requested-worktree-path (directory requested-path)
  (when requested-path
    (when (zerop (length requested-path))
      (%signal-init-error :worktree-conflict "Worktree path is empty"))
    (uiop:ensure-directory-pathname
     (merge-pathnames (pathname requested-path) directory))))

(defun %preflight-init-worktree (directory requested-path)
  (let ((path (%requested-worktree-path directory requested-path)))
    (when path
      (when (probe-file path)
        (%signal-init-error :worktree-conflict
                            "Worktree path already exists: ~A" path))
      (let* ((listing (%init-git-output
                       '("worktree" "list" "--porcelain" "-z")
                       directory "inspecting worktrees"))
             (needle (format nil "worktree ~A~C"
                             (string-right-trim
                              '(#\/)
                              (uiop:native-namestring path))
                             #\Null)))
        (when (search needle listing :test #'char=)
          (%signal-init-error :worktree-conflict
                              "Worktree path is already registered: ~A" path))))
    path))

(defun %preflight-init (directory source-ref requested-path)
  (%init-git-output '("rev-parse" "--git-dir") directory
                    "locating the repository")
  (%preflight-init-history directory)
  (when (ref-state-exists-p (inspect-ref source-ref directory))
    (%signal-init-error :branch-exists
                        "Source branch already exists: ~S" source-ref))
  (when (protocol-refs directory)
    (%signal-init-error :existing-metadata
                        "Local refs/gaw metadata already exists"))
  (let ((configuration (inspect-protection-hook directory)))
    (when (eq :conflict (hook-configuration-status configuration))
      (%signal-init-error :hook-conflict "~A"
                          (hook-configuration-detail configuration))))
  (%preflight-init-worktree directory requested-path))

(defun %make-tree-object (directory entries operation)
  (%init-git-output
   '("mktree" "-z") directory operation
   :input (string-to-octets entries :encoding :utf-8)))

(defun %create-initial-commit (directory config-text message
                              identity-name identity-email)
  (let* ((config-octets (string-to-octets config-text :encoding :utf-8))
         (blob (%init-git-output '("hash-object" "-w" "--stdin")
                                 directory "writing the initial config blob"
                                 :input config-octets))
         (gaw-tree
           (%make-tree-object
            directory
            (format nil "100644 blob ~A~Cconfig~C" blob #\Tab #\Null)
            "writing the initial .gaw tree"))
         (root-tree
           (%make-tree-object
            directory
            (format nil "040000 tree ~A~C.gaw~C" gaw-tree #\Tab #\Null)
            "writing the initial root tree")))
    (%init-git-output
     (list "-c" (format nil "user.name=~A" identity-name)
           "-c" (format nil "user.email=~A" identity-email)
           "-c" "commit.gpgSign=false"
           "commit-tree" root-tree "-m" message)
     directory "writing the initial root commit")))

(defun %initialize (directory branch requested-path source-ref-prefix
                    config-text message identity-name identity-email)
  (check-type directory pathname)
  (let* ((source-ref (%init-source-ref branch directory source-ref-prefix))
         (worktree-path (%preflight-init directory source-ref requested-path))
         (commit-oid (%create-initial-commit
                      directory config-text message identity-name identity-email)))
    (unless (committed-state-report-ok-p
             (inspect-committed-state directory commit-oid))
      (%signal-init-error :invalid-initial-state
                          "The generated initial commit failed validation"))
    (initialize-ref-graph source-ref commit-oid directory)
    (handler-case
        (let ((deploy-result
                (deploy directory :branch branch
                                  :worktree-path
                                  (and worktree-path
                                       (uiop:native-namestring worktree-path)))))
          (%make-init-result source-ref branch commit-oid deploy-result))
      (error (condition)
        (handler-case
            (remove-initial-ref-graph source-ref commit-oid directory)
          (error (rollback)
            (%signal-init-error
             :partial-failure
             "Deployment failed (~A) and ref compensation failed: ~A"
             condition rollback)))
        (%signal-init-error :deployment-failed "~A" condition)))))
