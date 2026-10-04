(in-package #:git-agent-workflow.mutation)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%select-source-ref %restore-source-selection
                      %initialize-source-and-selector
                      %remove-initial-source-and-selector
                      %rename-selected-source %delete-selector
                      %delete-symbolic-ref
                      %run-branch %run-worktree %run-source-ref-update))
    (unless (fboundp function)
      (error "Required mutation runtime function is unavailable: ~S"
             function))))

(defun select-source-ref (source-ref directory)
  (%select-source-ref source-ref directory (hook-disable-options)))

(defun restore-source-selection (change directory)
  (%restore-source-selection change directory (hook-disable-options)))

(defun initialize-source-and-selector (source-ref object-id directory)
  (%initialize-source-and-selector source-ref object-id directory
                                   (hook-disable-options)))

(defun remove-initial-source-and-selector (source-ref object-id directory)
  (%remove-initial-source-and-selector source-ref object-id directory
                                      (hook-disable-options)))

(defun rename-selected-source (old-source-ref new-source-ref directory)
  (%rename-selected-source old-source-ref new-source-ref directory
                           (hook-disable-options)))

(defun delete-selector (directory)
  (%delete-selector directory (hook-disable-options)))

(defun delete-symbolic-ref (ref target directory)
  (%delete-symbolic-ref ref target directory (hook-disable-options)))

(defun run-branch (arguments directory)
  (%run-branch arguments directory (hook-disable-options)))

(defun run-worktree (arguments directory)
  (%run-worktree arguments directory (hook-disable-options)))

(defun run-source-ref-update (source-ref old-oid new-oid
                              directory reflog-message)
  (%run-source-ref-update source-ref old-oid new-oid directory
                          reflog-message (hook-disable-options)
                          (list "-c" "core.hooksPath=/dev/null")))
