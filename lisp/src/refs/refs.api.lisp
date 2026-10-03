(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%make-ref
                      %registered-ref-p
                      %register-ref
                      %unregister-ref
                      %list-refs
                      %select-ref
                      %restore-selection
                      %initialize-ref-graph
                      %remove-initial-ref-graph
                      %rename-ref-registration
                      %remove-ref-registration
                      %restore-ref-registration))
    (unless (fboundp function)
      (error "Required refs runtime function is unavailable: ~S"
             function))))

(defparameter *display-name*
  "GAW")

(defparameter *source-ref-prefix*
  "refs/heads/")

(defparameter *target-ref-prefix*
  "refs/gaw/heads/")

(defparameter *protocol-ref-prefix*
  "refs/gaw/")

(defparameter *head-ref*
  "refs/gaw/HEAD")

(defun make-ref (source-ref)
  (%make-ref source-ref
             *source-ref-prefix*
             *target-ref-prefix*))

(defun registered-ref-p (source-ref directory)
  (%registered-ref-p source-ref
                     directory
                     *source-ref-prefix*
                     *target-ref-prefix*))

(defun register-ref (source-ref directory &key overwrite git-options)
  (%register-ref source-ref
                 directory
                 overwrite
                 *display-name*
                 *source-ref-prefix*
                 *target-ref-prefix*
                 git-options))

(defun unregister-ref (target-ref directory &key git-options)
  (%unregister-ref target-ref
                   directory
                   *display-name*
                   *target-ref-prefix*
                   git-options))

(defun registration-refs (directory)
  (%list-refs *target-ref-prefix* directory))

(defun protocol-refs (directory)
  (%list-refs *protocol-ref-prefix* directory))

(defun select-ref (source-ref directory &key git-options)
  (%select-ref source-ref directory
               *source-ref-prefix* *target-ref-prefix* *head-ref*
               git-options))

(defun restore-selection (change directory &key git-options)
  (%restore-selection change directory git-options))

(defun initialize-ref-graph (source-ref object-id directory &key git-options)
  (%initialize-ref-graph source-ref object-id directory
                         *source-ref-prefix* *target-ref-prefix* *head-ref*
                         git-options))

(defun remove-initial-ref-graph (source-ref object-id directory
                                 &key git-options)
  (%remove-initial-ref-graph source-ref object-id directory
                             *source-ref-prefix* *target-ref-prefix* *head-ref*
                             git-options))

(defun rename-ref-registration (old-source-ref new-source-ref directory
                                &key git-options)
  (%rename-ref-registration old-source-ref new-source-ref directory
                            *source-ref-prefix* *target-ref-prefix* *head-ref*
                            git-options))

(defun remove-ref-registration (source-ref directory &key git-options)
  (%remove-ref-registration source-ref directory
                            *source-ref-prefix* *target-ref-prefix* *head-ref*
                            git-options))

(defun restore-ref-registration (removal directory &key git-options)
  (%restore-ref-registration removal directory git-options))
