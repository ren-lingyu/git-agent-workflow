(in-package #:git-agent-workflow.help)

(define-condition help-error (error)
  ((reason :initarg :reason
           :reader help-error-reason)
   (topic :initarg :topic
          :reader help-error-topic))
  (:report (lambda (condition stream)
             (format stream "GAW help failed (~S): unknown topic ~S"
                     (help-error-reason condition)
                     (help-error-topic condition)))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %read-help-source-octets (relative-path)
    (let ((path (asdf:system-relative-pathname
                 "git-agent-workflow" relative-path)))
      (with-open-file (stream path :direction :input
                                  :element-type '(unsigned-byte 8))
        (let* ((length (file-length stream))
               (octets (make-array length
                                   :element-type '(unsigned-byte 8))))
          (unless (= (read-sequence octets stream) length)
            (error "Could not read complete help source: ~A" path))
          octets))))

  (defun %read-help-source (relative-path)
    (let ((octets (%read-help-source-octets relative-path)))
      (when (and (>= (length octets) 3)
                 (= (aref octets 0) #xef)
                 (= (aref octets 1) #xbb)
                 (= (aref octets 2) #xbf))
        (error "Help source must not contain a UTF-8 BOM: ~A" relative-path))
      (unless (and (plusp (length octets))
                   (= (aref octets (1- (length octets))) 10))
        (error "Help source must end with LF: ~A" relative-path))
      (octets-to-string octets :encoding :utf-8 :errorp t)))

  (defmacro %define-help-text (name relative-path)
    `(defparameter ,name ,(%read-help-source relative-path))))

(%define-help-text *overview-help* "src/help/text/overview.txt")
(%define-help-text *commit-help* "src/help/text/commit.txt")
(%define-help-text *show-help* "src/help/text/show.txt")
(%define-help-text *check-help* "src/help/text/check.txt")
(%define-help-text *status-help* "src/help/text/status.txt")
(%define-help-text *deploy-help* "src/help/text/deploy.txt")
(%define-help-text *init-help* "src/help/text/init.txt")
(%define-help-text *branch-help* "src/help/text/branch.txt")

(defun %help-text (topic)
  (case topic
    (:overview *overview-help*)
    (:commit *commit-help*)
    (:show *show-help*)
    (:check *check-help*)
    (:status *status-help*)
    (:deploy *deploy-help*)
    (:init *init-help*)
    (:branch *branch-help*)
    (otherwise
     (error 'help-error :reason :unknown-topic :topic topic))))
