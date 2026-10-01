(in-package #:git-agent-workflow.deploy)

(define-condition deploy-error (error)
  ((reason :initarg :reason :reader deploy-error-reason)
   (detail :initarg :detail :reader deploy-error-detail))
  (:report (lambda (condition stream)
             (format stream "GAW deploy failed (~(~A~)): ~A"
                     (deploy-error-reason condition)
                     (deploy-error-detail condition)))))

(defun %signal-deploy-error (reason control &rest arguments)
  (error 'deploy-error
         :reason reason
         :detail (apply #'format nil control arguments)))

(defstruct (deploy-result
            (:constructor %make-deploy-result
                (source-ref branch mode worktree-path warnings))
            (:copier nil))
  (source-ref "" :type string :read-only t)
  (branch "" :type string :read-only t)
  (mode nil :type (member :repository-only
                          :existing-worktree
                          :created-worktree)
        :read-only t)
  (worktree-path nil :type (or null pathname) :read-only t)
  (warnings '() :type list :read-only t))

(defstruct (%worktree-record
            (:constructor %make-worktree-record
                (path branch detached-p prunable-p))
            (:copier nil))
  (path "" :type string :read-only t)
  (branch nil :type (or null string) :read-only t)
  (detached-p nil :type boolean :read-only t)
  (prunable-p nil :type boolean :read-only t))
