(in-package #:git-agent-workflow.check)

(define-condition check-error (error)
  ((reason :initarg :reason
           :reader check-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader %check-error-detail))
  (:report (lambda (condition stream)
             (if (%check-error-detail condition)
                 (format stream "GAW check failed (~S): ~A"
                         (check-error-reason condition)
                         (%check-error-detail condition))
                 (format stream "GAW check failed (~S)"
                         (check-error-reason condition))))))

(defstruct (check-finding
            (:constructor %make-check-finding (name status detail))
            (:copier nil))
  (name nil :type keyword :read-only t)
  (status nil :type (member :ok :warning :error :skipped) :read-only t)
  (detail "" :type string :read-only t))

(defstruct (check-report
            (:constructor %make-check-report (root findings))
            (:copier nil))
  (root nil :type (or null pathname) :read-only t)
  (findings '() :type list :read-only t))

(defun check-report-ok-p (report)
  (check-type report check-report)
  (not (find :error (check-report-findings report)
             :key #'check-finding-status)))

(defun write-check-report (report &optional (stream *standard-output*))
  (check-type report check-report)
  (dolist (finding (check-report-findings report))
    (format stream "[~(~A~)] ~(~A~): ~A~%"
            (check-finding-status finding)
            (check-finding-name finding)
            (check-finding-detail finding)))
  (format stream "~%GAW worktree is ~:[not ready~;ready~].~%"
          (check-report-ok-p report))
  report)

(defun %signal-check-error (reason control &rest arguments)
  (error 'check-error
         :reason reason
         :detail (when control (apply #'format nil control arguments))))
