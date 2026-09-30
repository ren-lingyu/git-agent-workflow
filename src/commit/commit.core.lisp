(in-package #:git-agent-workflow.commit)

(define-condition commit-error (error)
  ((reason :initarg :reason
           :reader commit-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader %commit-error-detail))
  (:report (lambda (condition stream)
             (if (%commit-error-detail condition)
                 (format stream
                         "GAW commit failed (~S): ~A"
                         (commit-error-reason condition)
                         (%commit-error-detail condition))
                 (format stream
                         "GAW commit failed (~S)"
                         (commit-error-reason condition))))))

(defun %signal-commit-error (reason control &rest arguments)
  (error 'commit-error
         :reason reason
         :detail (when control
                   (apply #'format nil control arguments))))

(defun %call-with-workspace-error-as-commit-error (thunk)
  (handler-case
      (funcall thunk)
    (workspace-error (condition)
      (%signal-commit-error (workspace-error-reason condition)
                            "~A"
                            (or (workspace-error-detail condition)
                                condition)))))
