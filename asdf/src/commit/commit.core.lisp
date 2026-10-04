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

(defun %validate-commit-input (message project-commits
                               allow-empty-message)
  (unless (typep message '(vector (unsigned-byte 8)))
    (error 'type-error
           :datum message
           :expected-type '(vector (unsigned-byte 8))))
  (unless (and (listp project-commits)
               (every #'stringp project-commits))
    (error 'type-error
           :datum project-commits
           :expected-type 'list))
  (when (and (zerop (length message))
             (not allow-empty-message))
    (%signal-commit-error :empty-message
                          "The commit message is empty")))

(defun %workspace-declarations (config)
  (mapcar (lambda (entry)
            (cons (workspace-entry-kind entry)
                  (workspace-entry-path entry)))
          (config-workspace config)))
