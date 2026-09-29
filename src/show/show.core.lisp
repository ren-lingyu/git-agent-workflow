(in-package #:git-agent-workflow.show)

(define-condition show-error (error)
  ((reason :initarg :reason
           :reader show-error-reason)
   (argument :initarg :argument
             :reader %show-error-argument))
  (:report (lambda (condition stream)
             (format stream
                     "GAW show failed (~S): unsupported option ~A"
                     (show-error-reason condition)
                     (%show-error-argument condition)))))

(defun %signal-unsupported-option (argument)
  (error 'show-error
         :reason :unsupported-option
         :argument argument))

(defun %diff-merges-value (argument)
  (let ((prefix "--diff-merges="))
    (when (and (> (length argument)
                  (length prefix))
               (string= prefix
                        argument
                        :end2 (length prefix)))
      (subseq argument
              (length prefix)))))

(defun %merge-mode (argument)
  (cond
    ((string= argument "--no-diff-merges")
     :off)
    ((string= argument "--dd")
     :first-parent)
    (t
     (let ((value (%diff-merges-value argument)))
       (cond
         ((and value
               (member value
                       '("off" "none")
                       :test #'string=))
          :off)
         ((and value
               (member value
                       '("first-parent" "1")
                       :test #'string=))
          :first-parent)
         ((and value
               (member value
                       '("on"
                         "m"
                         "separate"
                         "combined"
                         "c"
                         "dense-combined"
                         "cc"
                         "remerge"
                         "r")
                       :test #'string=))
          :unsupported)
         (t
          nil))))))

(defun %prepare-show-arguments (arguments)
  (unless (and (listp arguments)
               (every #'stringp arguments))
    (error 'type-error
           :datum arguments
           :expected-type 'list))
  (let* ((separator (position "--"
                              arguments
                              :test #'string=))
         (show-arguments (if separator
                             (subseq arguments 0 separator)
                             (copy-list arguments)))
         (pathspec (when separator
                     (subseq arguments separator)))
         (merge-mode nil))
    (dolist (argument show-arguments)
      (when (member argument
                    '("-m" "-c" "--cc" "--remerge-diff")
                    :test #'string=)
        (%signal-unsupported-option argument))
      (let ((mode (%merge-mode argument)))
        (when (eq mode :unsupported)
          (%signal-unsupported-option argument))
        (when mode
          (setf merge-mode mode))))
    (append (list "show")
            show-arguments
            (list "--first-parent")
            (unless (eq merge-mode :off)
              (list "--diff-merges=first-parent"))
            pathspec)))
