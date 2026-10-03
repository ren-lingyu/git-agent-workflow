(in-package #:git-agent-workflow.mutation)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%register-ref %unregister-ref %select-ref
                      %restore-selection %initialize-ref-graph
                      %remove-initial-ref-graph %rename-ref-registration
                      %remove-ref-registration %restore-ref-registration
                      %run-branch %run-worktree %run-source-ref-update))
    (unless (fboundp function)
      (error "Required mutation runtime function is unavailable: ~S"
             function))))

(defun register-ref (source-ref directory &key overwrite)
  (%register-ref source-ref directory overwrite (hook-disable-options)))

(defun unregister-ref (target-ref directory)
  (%unregister-ref target-ref directory (hook-disable-options)))

(defun select-ref (source-ref directory)
  (%select-ref source-ref directory (hook-disable-options)))

(defun restore-selection (change directory)
  (%restore-selection change directory (hook-disable-options)))

(defun initialize-ref-graph (source-ref object-id directory)
  (%initialize-ref-graph source-ref object-id directory
                         (hook-disable-options)))

(defun remove-initial-ref-graph (source-ref object-id directory)
  (%remove-initial-ref-graph source-ref object-id directory
                             (hook-disable-options)))

(defun rename-ref-registration (old-source-ref new-source-ref directory)
  (%rename-ref-registration old-source-ref new-source-ref directory
                            (hook-disable-options)))

(defun remove-ref-registration (source-ref directory)
  (%remove-ref-registration source-ref directory (hook-disable-options)))

(defun restore-ref-registration (removal directory)
  (%restore-ref-registration removal directory (hook-disable-options)))

(defun run-branch (arguments directory)
  (%run-branch arguments directory (hook-disable-options)))

(defun run-worktree (arguments directory)
  (%run-worktree arguments directory (hook-disable-options)))

(defun run-source-ref-update (source-ref old-oid new-oid
                              directory reflog-message)
  (%run-source-ref-update source-ref old-oid new-oid directory
                          reflog-message (hook-disable-options)
                          (list "-c" "core.hooksPath=/dev/null")))
