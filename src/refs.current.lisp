(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(inspect-ref
                      ref-state-exists-p
                      ref-state-symbolic-p
                      ref-state-symbolic-target
                      %ref-under-prefix-p))
    (unless (fboundp function)
      (error "Required refs function is unavailable: ~S"
             function)))
  (dolist (variable '(*display-name*
                      *source-ref-prefix*
                      *target-ref-prefix*))
    (unless (boundp variable)
      (error "Required refs variable is unavailable: ~S"
             variable))))

(defparameter *head-ref*
  "refs/gaw/HEAD")

(define-condition current-ref-error (error)
  ((reason :initarg :reason
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
                        *display-name*
                        (current-ref-error-ref condition)))
               (:direct-head
                (format stream
                        "~A HEAD is not a symbolic ref: ~S"
                        *display-name*
                        (current-ref-error-ref condition)))
               (:invalid-head-target
                (format stream
                        "~A HEAD does not point to a branch registration: ~S"
                        *display-name*
                        (current-ref-error-target condition)))
               (:missing-registration
                (format stream
                        "~A branch registration does not exist: ~S"
                        *display-name*
                        (current-ref-error-ref condition)))
               (:direct-registration
                (format stream
                        "~A branch registration is not a symbolic ref: ~S"
                        *display-name*
                        (current-ref-error-ref condition)))
               (:invalid-registration-target
                (format stream
                        "~A branch registration has an invalid target: ~S"
                        *display-name*
                        (current-ref-error-target condition)))
               (:dangling-registration
                (format stream
                        "~A branch registration is dangling: ~S"
                        *display-name*
                        (current-ref-error-ref condition)))
               (otherwise
                (format stream
                        "Failed to determine current ~A ref: ~S"
                        *display-name*
                        (current-ref-error-reason condition)))))))

(defun current-ref (directory)
  (let ((head-state (inspect-ref *head-ref*
                                 directory)))
    (unless (ref-state-exists-p head-state)
      (error 'current-ref-error
             :reason :missing-head
             :ref *head-ref*))
    (unless (ref-state-symbolic-p head-state)
      (error 'current-ref-error
             :reason :direct-head
             :ref *head-ref*))
    (let ((registration-ref
            (ref-state-symbolic-target head-state)))
      (unless (%ref-under-prefix-p registration-ref
                                   *target-ref-prefix*)
        (error 'current-ref-error
               :reason :invalid-head-target
               :ref *head-ref*
               :target registration-ref))
      (let ((registration-state
              (inspect-ref registration-ref
                           directory)))
        (unless (ref-state-exists-p registration-state)
          (error 'current-ref-error
                 :reason :missing-registration
                 :ref registration-ref))
        (unless (ref-state-symbolic-p registration-state)
          (error 'current-ref-error
                 :reason :direct-registration
                 :ref registration-ref))
        (let ((source-ref
                (ref-state-symbolic-target registration-state)))
          (unless (%ref-under-prefix-p source-ref
                                       *source-ref-prefix*)
            (error 'current-ref-error
                   :reason :invalid-registration-target
                   :ref registration-ref
                   :target source-ref))
          (unless (ref-state-exists-p
                   (inspect-ref source-ref
                                directory))
            (error 'current-ref-error
                   :reason :dangling-registration
                   :ref registration-ref
                   :target source-ref))
          source-ref)))))
