(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%make-ref
                      %register-ref
                      %unregister-ref))
    (unless (fboundp function)
      (error "Required refs library function is unavailable: ~S"
             function))))

(defparameter *display-name*
  "GAW")

(defparameter *source-ref-prefix*
  "refs/heads/")

(defparameter *target-ref-prefix*
  "refs/gaw/heads/")

(defun make-ref (source-ref)
  (%make-ref source-ref
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
