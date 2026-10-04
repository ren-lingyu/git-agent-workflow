(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%list-refs %select-source-ref
                      %restore-source-selection
                      %initialize-source-and-selector
                      %remove-initial-source-and-selector
                      %rename-selected-source %delete-selector
                      %delete-symbolic-ref))
    (unless (fboundp function)
      (error "Required refs runtime function is unavailable: ~S"
             function))))

(defparameter *display-name* "GAW")
(defparameter *source-ref-prefix* "refs/heads/")
(defparameter *protocol-ref-prefix* "refs/gaw/")
(defparameter *head-ref* "refs/gaw/HEAD")

(defun protocol-refs (directory)
  (%list-refs *protocol-ref-prefix* directory))

(defun select-source-ref (source-ref directory &key git-options)
  (%select-source-ref source-ref directory *source-ref-prefix* *head-ref*
                      git-options))

(defun restore-source-selection (change directory &key git-options)
  (%restore-source-selection change directory git-options))

(defun initialize-source-and-selector (source-ref object-id directory
                                        &key git-options)
  (%initialize-source-and-selector source-ref object-id directory
                                   *source-ref-prefix* *head-ref* git-options))

(defun remove-initial-source-and-selector (source-ref object-id directory
                                            &key git-options)
  (%remove-initial-source-and-selector source-ref object-id directory
                                      *head-ref* git-options))

(defun rename-selected-source (old-source-ref new-source-ref directory
                                &key git-options)
  (%rename-selected-source old-source-ref new-source-ref directory
                           *head-ref* git-options))

(defun delete-selector (directory &key git-options)
  (%delete-selector directory *head-ref* git-options))

(defun delete-symbolic-ref (ref target directory &key git-options)
  (%delete-symbolic-ref ref target directory git-options))
