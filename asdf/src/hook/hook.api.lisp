(in-package #:git-agent-workflow.hook)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%reference-transaction)
    (error "Required hook API dependency is unavailable: ~S"
           '%reference-transaction))
  (dolist (function '(%inspect-protection-hook
                      %ensure-protection-hook
                      %remove-protection-hook
                      %source-ref-for-transaction-ref))
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

(defun hook-disable-options ()
  (list "-c"
        (concatenate 'string *hook-enabled-key* "=false")))

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

(defun remove-protection-hook (directory)
  (%remove-protection-hook directory
                           (list *hook-event-key*
                                 *hook-command-key*
                                 *hook-enabled-key*)))

(defun reference-transaction (phase directory input-stream)
  (let ((source-ref-prefix *source-ref-prefix*))
    (handler-case
        (%reference-transaction
         phase directory input-stream
         (lambda (update hook-directory)
           (%source-ref-for-transaction-ref update hook-directory
                                            source-ref-prefix))
         #'inspect-ref
         #'marker-entry
         #'inspect-committed-state
         #'committed-state-classification
         *protocol-ref-prefix*)
      (hook-error (condition)
        (error condition))
      (error (condition)
        (%signal-hook-error :runtime-failure
                            :detail (princ-to-string condition)
                            :cause condition)))))
