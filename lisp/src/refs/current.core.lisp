(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(ref-state-exists-p
                      ref-state-symbolic-p
                      ref-state-symbolic-target
                      %ref-under-prefix-p))
    (unless (fboundp function)
      (error "Required refs core function is unavailable: ~S"
             function))))

(define-condition current-ref-error (error)
  ((display-name :initarg :display-name
                 :reader current-ref-error-display-name)
   (reason :initarg :reason
           :reader current-ref-error-reason)
   (ref :initarg :ref
        :reader current-ref-error-ref)
   (target :initarg :target
           :initform nil
           :reader current-ref-error-target))
  (:report (lambda (condition stream)
             (case (current-ref-error-reason condition)
               (:missing-head
                (format stream
                        "~A HEAD does not exist: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-ref condition)))
               (:direct-head
                (format stream
                        "~A HEAD is not a symbolic ref: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-ref condition)))
               (:invalid-head-target
                (format stream
                        "~A HEAD does not point to a branch registration: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-target condition)))
               (:missing-registration
                (format stream
                        "~A branch registration does not exist: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-ref condition)))
               (:direct-registration
                (format stream
                        "~A branch registration is not a symbolic ref: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-ref condition)))
               (:invalid-registration-target
                (format stream
                        "~A branch registration has an invalid target: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-target condition)))
               (:dangling-registration
                (format stream
                        "~A branch registration is dangling: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-ref condition)))
               (otherwise
                (format stream
                        "Failed to determine current ~A ref: ~S"
                        (current-ref-error-display-name condition)
                        (current-ref-error-reason condition)))))))

(defun %current-registration-ref (head-state
                                  display-name
                                  head-ref
                                  target-ref-prefix)
  (unless (ref-state-exists-p head-state)
    (error 'current-ref-error
           :display-name display-name
           :reason :missing-head
           :ref head-ref))
  (unless (ref-state-symbolic-p head-state)
    (error 'current-ref-error
           :display-name display-name
           :reason :direct-head
           :ref head-ref))
  (let ((registration-ref
          (ref-state-symbolic-target head-state)))
    (unless (%ref-under-prefix-p registration-ref
                                 target-ref-prefix)
      (error 'current-ref-error
             :display-name display-name
             :reason :invalid-head-target
             :ref head-ref
             :target registration-ref))
    registration-ref))

(defun %current-source-ref (registration-state
                            display-name
                            registration-ref
                            source-ref-prefix)
  (unless (ref-state-exists-p registration-state)
    (error 'current-ref-error
           :display-name display-name
           :reason :missing-registration
           :ref registration-ref))
  (unless (ref-state-symbolic-p registration-state)
    (error 'current-ref-error
           :display-name display-name
           :reason :direct-registration
           :ref registration-ref))
  (let ((source-ref
          (ref-state-symbolic-target registration-state)))
    (unless (%ref-under-prefix-p source-ref
                                 source-ref-prefix)
      (error 'current-ref-error
             :display-name display-name
             :reason :invalid-registration-target
             :ref registration-ref
             :target source-ref))
    source-ref))

(defun %ensure-current-source-exists (source-state
                                      display-name
                                      registration-ref
                                      source-ref)
  (unless (ref-state-exists-p source-state)
    (error 'current-ref-error
           :display-name display-name
           :reason :dangling-registration
           :ref registration-ref
           :target source-ref))
  source-ref)
