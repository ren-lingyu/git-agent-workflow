(in-package #:git-agent-workflow.mutation)

(defun %select-source-ref (source-ref directory git-options)
  (git-agent-workflow.refs:select-source-ref
   source-ref directory :git-options git-options))

(defun %restore-source-selection (change directory git-options)
  (git-agent-workflow.refs:restore-source-selection
   change directory :git-options git-options))

(defun %initialize-source-and-selector (source-ref object-id directory
                                        git-options)
  (git-agent-workflow.refs:initialize-source-and-selector
   source-ref object-id directory :git-options git-options))

(defun %remove-initial-source-and-selector (source-ref object-id directory
                                            git-options)
  (git-agent-workflow.refs:remove-initial-source-and-selector
   source-ref object-id directory :git-options git-options))

(defun %rename-selected-source (old-source-ref new-source-ref directory
                                git-options)
  (git-agent-workflow.refs:rename-selected-source
   old-source-ref new-source-ref directory :git-options git-options))

(defun %delete-selector (directory git-options)
  (git-agent-workflow.refs:delete-selector
   directory :git-options git-options))

(defun %delete-symbolic-ref (ref target directory git-options)
  (git-agent-workflow.refs:delete-symbolic-ref
   ref target directory :git-options git-options))

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
