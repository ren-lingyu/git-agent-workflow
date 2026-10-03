(in-package #:git-agent-workflow.mutation)

(defun register-ref (source-ref directory &key overwrite)
  (git-agent-workflow.refs:register-ref
   source-ref directory
   :overwrite overwrite
   :git-options (hook-disable-options)))

(defun unregister-ref (target-ref directory)
  (git-agent-workflow.refs:unregister-ref
   target-ref directory
   :git-options (hook-disable-options)))

(defun select-ref (source-ref directory)
  (git-agent-workflow.refs:select-ref
   source-ref directory
   :git-options (hook-disable-options)))

(defun restore-selection (change directory)
  (git-agent-workflow.refs:restore-selection
   change directory
   :git-options (hook-disable-options)))

(defun initialize-ref-graph (source-ref object-id directory)
  (git-agent-workflow.refs:initialize-ref-graph
   source-ref object-id directory
   :git-options (hook-disable-options)))

(defun remove-initial-ref-graph (source-ref object-id directory)
  (git-agent-workflow.refs:remove-initial-ref-graph
   source-ref object-id directory
   :git-options (hook-disable-options)))

(defun rename-ref-registration (old-source-ref new-source-ref directory)
  (git-agent-workflow.refs:rename-ref-registration
   old-source-ref new-source-ref directory
   :git-options (hook-disable-options)))

(defun remove-ref-registration (source-ref directory)
  (git-agent-workflow.refs:remove-ref-registration
   source-ref directory
   :git-options (hook-disable-options)))

(defun restore-ref-registration (removal directory)
  (git-agent-workflow.refs:restore-ref-registration
   removal directory
   :git-options (hook-disable-options)))

(defun run-branch (arguments directory)
  (run-git
   (append (hook-disable-options)
           (cons "branch" arguments))
   directory))

(defun run-worktree (arguments directory)
  (run-git
   (append (hook-disable-options)
           (cons "worktree" arguments))
   directory))

(defun run-source-ref-update (source-ref old-oid new-oid
                              directory reflog-message)
  (run-git
   (append (list "-c" "core.hooksPath=/dev/null")
           (hook-disable-options)
           (list "update-ref"
                 "-m"
                 reflog-message
                 source-ref
                 new-oid
                 old-oid))
   directory))
