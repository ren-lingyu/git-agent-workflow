(in-package #:git-agent-workflow.mutation)

(defun %register-ref (source-ref directory overwrite git-options)
  (git-agent-workflow.refs:register-ref
   source-ref directory :overwrite overwrite :git-options git-options))

(defun %unregister-ref (target-ref directory git-options)
  (git-agent-workflow.refs:unregister-ref
   target-ref directory :git-options git-options))

(defun %select-ref (source-ref directory git-options)
  (git-agent-workflow.refs:select-ref
   source-ref directory :git-options git-options))

(defun %restore-selection (change directory git-options)
  (git-agent-workflow.refs:restore-selection
   change directory :git-options git-options))

(defun %initialize-ref-graph (source-ref object-id directory git-options)
  (git-agent-workflow.refs:initialize-ref-graph
   source-ref object-id directory :git-options git-options))

(defun %remove-initial-ref-graph (source-ref object-id directory git-options)
  (git-agent-workflow.refs:remove-initial-ref-graph
   source-ref object-id directory :git-options git-options))

(defun %rename-ref-registration (old-source-ref new-source-ref
                                  directory git-options)
  (git-agent-workflow.refs:rename-ref-registration
   old-source-ref new-source-ref directory :git-options git-options))

(defun %remove-ref-registration (source-ref directory git-options)
  (git-agent-workflow.refs:remove-ref-registration
   source-ref directory :git-options git-options))

(defun %restore-ref-registration (removal directory git-options)
  (git-agent-workflow.refs:restore-ref-registration
   removal directory :git-options git-options))

(defun %run-branch (arguments directory git-options)
  (run-git (%protected-command-arguments git-options "branch" arguments)
           directory))

(defun %run-worktree (arguments directory git-options)
  (run-git (%protected-command-arguments git-options "worktree" arguments)
           directory))

(defun %run-source-ref-update (source-ref old-oid new-oid
                                directory reflog-message git-options
                                traditional-hook-options)
  (run-git (%source-ref-update-arguments
            source-ref old-oid new-oid reflog-message
            git-options traditional-hook-options)
           directory))
