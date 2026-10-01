(in-package #:git-agent-workflow.hook)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%reference-transaction)
    (error "Required hook API dependency is unavailable: ~S"
           '%reference-transaction))
  (dolist (function '(%inspect-protection-hook %ensure-protection-hook))
    (unless (fboundp function)
      (error "Required hook configuration dependency is unavailable: ~S"
             function))))

(defparameter *source-ref-prefix*
  "refs/heads/")

(defparameter *protocol-ref-prefix*
  "refs/gaw/")

(defparameter *hook-event-key*
  "hook.gaw-reference-transaction.event")

(defparameter *hook-command-key*
  "hook.gaw-reference-transaction.command")

(defparameter *hook-enabled-key*
  "hook.gaw-reference-transaction.enabled")

(defparameter *hook-event*
  "reference-transaction")

(defparameter *hook-command*
  "git-gaw --reference-transaction")

(defun inspect-protection-hook (directory)
  (%inspect-protection-hook directory
                            *hook-event-key*
                            *hook-command-key*
                            *hook-enabled-key*
                            *hook-event*
                            *hook-command*))

(defun ensure-protection-hook (directory)
  (%ensure-protection-hook directory
                           *hook-event-key*
                           *hook-command-key*
                           *hook-enabled-key*
                           *hook-event*
                           *hook-command*))

(defun %resolve-symbolic-source-ref (ref directory)
  (let ((seen (make-hash-table :test #'equal))
        (current ref))
    (loop
      (when (gethash current seen)
        (error "Symbolic ref cycle while resolving ~S" ref))
      (setf (gethash current seen) t)
      (let ((state (inspect-ref current directory)))
        (unless (and (ref-state-exists-p state)
                     (ref-state-symbolic-p state))
          (return nil))
        (let ((target (ref-state-symbolic-target state)))
          (when (%ref-under-prefix-p target *source-ref-prefix*)
            (return target))
          (setf current target))))))

(defun %source-ref-for-transaction-ref (update directory)
  (let ((transaction-ref (%reference-update-ref update)))
    (cond
      ((%ref-under-prefix-p transaction-ref *source-ref-prefix*)
       transaction-ref)
      ((%reference-update-symbolic-p update)
       nil)
      (t
       (%resolve-symbolic-source-ref transaction-ref directory)))))

(defun reference-transaction (phase directory input-stream)
  (handler-case
      (%reference-transaction phase
                              directory
                              input-stream
                              #'%source-ref-for-transaction-ref
                              #'registered-ref-p
                              *protocol-ref-prefix*)
    (hook-error (condition)
      (error condition))
    (error (condition)
      (%signal-hook-error :runtime-failure
                          :detail (princ-to-string condition)
                          :cause condition))))
