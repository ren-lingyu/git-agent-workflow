(in-package #:git-agent-workflow.init)

(define-condition init-error (error)
  ((reason :initarg :reason :reader init-error-reason)
   (detail :initarg :detail :reader init-error-detail))
  (:report (lambda (condition stream)
             (format stream "GAW init failed (~(~A~)): ~A"
                     (init-error-reason condition)
                     (init-error-detail condition)))))

(defun %signal-init-error (reason control &rest arguments)
  (error 'init-error :reason reason
         :detail (apply #'format nil control arguments)))

(defstruct (init-result
            (:constructor %make-init-result
                (source-ref branch commit-oid deploy-result))
            (:copier nil))
  (source-ref "" :type string :read-only t)
  (branch "" :type string :read-only t)
  (commit-oid "" :type string :read-only t)
  (deploy-result nil :read-only t))
