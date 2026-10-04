(in-package #:git-agent-workflow.branch)

(define-condition branch-error (error)
  ((reason :initarg :reason :reader branch-error-reason)
   (detail :initarg :detail :reader branch-error-detail))
  (:report (lambda (condition stream)
             (format stream "GAW branch operation failed (~(~A~)): ~A"
                     (branch-error-reason condition)
                     (branch-error-detail condition)))))

(defun %signal-branch-error (reason control &rest arguments)
  (error 'branch-error :reason reason
         :detail (apply #'format nil control arguments)))

(defstruct (branch-result
            (:constructor %make-branch-result
                (operation old-source-ref new-source-ref))
            (:copier nil))
  (operation nil :type (member :rename :delete) :read-only t)
  (old-source-ref "" :type string :read-only t)
  (new-source-ref nil :type (or null string) :read-only t))
