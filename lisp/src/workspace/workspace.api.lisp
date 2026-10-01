(in-package #:git-agent-workflow.workspace)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%worktree-root %current-local-head-ref %operation-states
                      %read-tree-snapshot %read-index-snapshot
                      %validate-snapshot-shape
                      %validate-workspace
                      %find-project-path-conflict))
    (unless (fboundp function)
      (error "Required workspace API dependency is unavailable: ~S" function))))

(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *protocol-root* ".gaw")
(defparameter *operation-state-paths*
  '("MERGE_HEAD" "CHERRY_PICK_HEAD" "REVERT_HEAD" "REBASE_HEAD"
    "rebase-merge" "rebase-apply" "sequencer" "BISECT_LOG"))
(defparameter *file-modes* '("100644" "100755" "120000"))
(defparameter *tree-mode* "040000")
(defparameter *gitlink-mode* "160000")
(defparameter *blob-type* "blob")
(defparameter *tree-type* "tree")
(defparameter *commit-type* "commit")

(defun worktree-root (directory)
  (%worktree-root directory))

(defun current-local-head-ref (directory)
  (%current-local-head-ref directory *source-ref-prefix*))

(defun operation-states (directory)
  (%operation-states directory *operation-state-paths*))

(defun read-tree-snapshot (directory tree-oid)
  (%read-tree-snapshot directory tree-oid))

(defun read-index-snapshot (directory)
  (%read-index-snapshot directory *gitlink-mode* *blob-type* *commit-type*
                        *tree-mode* *tree-type*))

(defun validate-snapshot-shape (entries)
  (%validate-snapshot-shape entries *file-modes* *tree-mode* *gitlink-mode*
                            *blob-type* *tree-type*))

(defun validate-workspace (workspace entries)
  (%validate-workspace workspace entries
                       (string-to-octets *protocol-root* :encoding :utf-8)
                       *file-modes* *tree-mode* *gitlink-mode*
                       *blob-type* *tree-type*))

(defun find-project-path-conflict (workspace entries)
  (%find-project-path-conflict
   workspace entries
   (string-to-octets *protocol-root* :encoding :utf-8)
   *tree-mode* *tree-type*))
