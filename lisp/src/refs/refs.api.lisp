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

(defun register-ref (source-ref directory &key overwrite)
  (%register-ref source-ref
                 directory
                 overwrite
                 *display-name*
                 *source-ref-prefix*
                 *target-ref-prefix*))

(defun unregister-ref (target-ref directory)
  (%unregister-ref target-ref
                   directory
                   *display-name*
                   *target-ref-prefix*))

(defun registration-refs (directory)
  (%list-refs *target-ref-prefix* directory))

(defun protocol-refs (directory)
  (%list-refs *protocol-ref-prefix* directory))

(defun select-ref (source-ref directory)
  (%select-ref source-ref directory
               *source-ref-prefix* *target-ref-prefix* *head-ref*))

(defun restore-selection (change directory)
  (%restore-selection change directory))

(defun initialize-ref-graph (source-ref object-id directory)
  (%initialize-ref-graph source-ref object-id directory
                         *source-ref-prefix* *target-ref-prefix* *head-ref*))

(defun remove-initial-ref-graph (source-ref object-id directory)
  (%remove-initial-ref-graph source-ref object-id directory
                             *source-ref-prefix* *target-ref-prefix* *head-ref*))

(defun rename-ref-registration (old-source-ref new-source-ref directory)
  (%rename-ref-registration old-source-ref new-source-ref directory
                            *source-ref-prefix* *target-ref-prefix* *head-ref*))

(defun remove-ref-registration (source-ref directory)
  (%remove-ref-registration source-ref directory
                            *source-ref-prefix* *target-ref-prefix* *head-ref*))

(defun restore-ref-registration (removal directory)
  (%restore-ref-registration removal directory))
