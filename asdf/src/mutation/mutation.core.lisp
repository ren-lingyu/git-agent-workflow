(in-package #:git-agent-workflow.mutation)

(defun %protected-command-arguments (git-options command arguments)
  (append git-options (cons command arguments)))

(defun %source-ref-update-arguments (source-ref old-oid new-oid
                                     reflog-message git-options
                                     traditional-hook-options)
  (append traditional-hook-options
          git-options
          (list "update-ref" "-m" reflog-message
                source-ref new-oid old-oid)))
