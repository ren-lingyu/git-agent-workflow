(in-package #:git-agent-workflow.hook)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%reference-transaction)
    (error "Required hook API dependency is unavailable: ~S"
           '%reference-transaction)))

(defparameter *source-ref-prefix*
  "refs/heads/")

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
                              #'registered-ref-p)
    (hook-error (condition)
      (error condition))
    (error (condition)
      (%signal-hook-error :runtime-failure
                          :detail (princ-to-string condition)
                          :cause condition))))
