(in-package #:git-agent-workflow.refs)

(define-condition current-ref-error (error)
  ((display-name :initarg :display-name
                 :reader current-ref-error-display-name)
   (reason :initarg :reason :reader current-ref-error-reason)
   (ref :initarg :ref :reader current-ref-error-ref)
   (target :initarg :target :initform nil
           :reader current-ref-error-target))
  (:report (lambda (condition stream)
             (format stream "Cannot resolve ~A selector (~(~A~)): ~A~@[ -> ~A~]"
                     (current-ref-error-display-name condition)
                     (current-ref-error-reason condition)
                     (current-ref-error-ref condition)
                     (current-ref-error-target condition)))))

(defun %current-source-target (head-state display-name head-ref source-prefix)
  (unless (ref-state-exists-p head-state)
    (error 'current-ref-error :display-name display-name
           :reason :missing-head :ref head-ref))
  (unless (ref-state-symbolic-p head-state)
    (error 'current-ref-error :display-name display-name
           :reason :direct-head :ref head-ref))
  (let ((source-ref (ref-state-symbolic-target head-state)))
    (unless (%ref-under-prefix-p source-ref source-prefix)
      (error 'current-ref-error :display-name display-name
             :reason :invalid-head-target :ref head-ref :target source-ref))
    source-ref))
