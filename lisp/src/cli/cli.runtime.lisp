(in-package #:git-agent-workflow.cli)

(defun %version ()
  (load-time-value
   (or (asdf:component-version
        (asdf:find-system "git-agent-workflow"))
       (error "The git-agent-workflow system has no version"))
   t))

(defun %read-octets (stream)
  (let ((buffer
          (make-array 0
                      :element-type '(unsigned-byte 8)
                      :adjustable t
                      :fill-pointer 0)))
    (loop for octet = (read-byte stream nil nil)
          while octet
          do (vector-push-extend octet buffer 4096))
    (let ((result
            (make-array (length buffer)
                        :element-type '(unsigned-byte 8))))
      (replace result buffer)
      result)))

(defun %read-message-file (path)
  (if (string= path "-")
      #+sbcl
      (let ((stream
              (sb-sys:make-fd-stream 0
                                     :input t
                                     :element-type
                                     '(unsigned-byte 8)
                                     :buffering :none
                                     :auto-close nil)))
        (%read-octets stream))
      #-sbcl
      (error "Binary standard input requires SBCL")
      (with-open-file (stream path
                              :direction :input
                              :element-type '(unsigned-byte 8))
        (%read-octets stream))))

(defun %append-octets (buffer octets)
  (loop for octet across octets
        do (vector-push-extend octet buffer 4096)))

(defun %message-from-fragments (fragments)
  (let ((buffer
          (make-array 0
                      :element-type '(unsigned-byte 8)
                      :adjustable t
                      :fill-pointer 0)))
    (dolist (fragment fragments)
      (when (plusp (length buffer))
        (vector-push-extend 10 buffer 4096))
      (ecase (car fragment)
        (:message
         (%append-octets buffer
                         (string-to-octets (cdr fragment)
                                           :encoding :utf-8))
         (when (and (plusp (length buffer))
                    (/= (aref buffer
                              (1- (length buffer)))
                        10))
           (vector-push-extend 10 buffer 4096)))
        (:file
         (%append-octets buffer
                         (%read-message-file (cdr fragment))))))
    (let ((result
            (make-array (length buffer)
                        :element-type '(unsigned-byte 8))))
      (replace result buffer)
      result)))

(defun %parse-commit-arguments (arguments)
  (multiple-value-bind (fragments project-commits
                        allow-empty allow-empty-message)
      (%parse-commit-options arguments)
    (values (%message-from-fragments fragments)
            project-commits
            allow-empty
            allow-empty-message)))

(defun %run-commit (arguments directory stream)
  (multiple-value-bind (message
                        project-commits
                        allow-empty
                        allow-empty-message)
      (%parse-commit-arguments arguments)
    (let ((oid (commit directory
                       message
                       :project-commits project-commits
                       :allow-empty allow-empty
                       :allow-empty-message allow-empty-message)))
      (format stream "~A~%" oid)
      0)))

(defun %run-show (arguments directory)
  (show directory arguments))

(defun %run-check (arguments directory stream)
  (when arguments
    (%cli-error "git gaw check does not accept arguments"))
  (let ((report (check directory)))
    (write-check-report report stream)
    (if (check-report-ok-p report) 0 1)))

(defun %run-status (arguments directory stream)
  (unless (or (null arguments)
              (equal arguments '("--diagnose")))
    (%cli-error "Usage: git gaw status [--diagnose]"))
  (let ((report (status directory)))
    (write-status-report report stream)
    (if arguments
        (progn
          (finish-output stream)
          (let ((diagnostic-status (diagnose-status directory)))
            (if (and (status-report-ok-p report)
                     (zerop diagnostic-status))
                0
                (if (zerop diagnostic-status) 1 diagnostic-status))))
        0)))

(defun %run-init (arguments directory stream)
  (multiple-value-bind (branch worktree-path)
      (%parse-deploy-arguments arguments)
    (unless branch
      (%cli-error "git gaw init requires --branch <name>"))
    (let ((result (initialize directory
                              :branch branch
                              :worktree-path worktree-path)))
      (format stream "Initialized GAW branch ~A at ~A (~(~A~))~%"
              (init-result-branch result)
              (init-result-commit-oid result)
              (deploy-result-mode (init-result-deploy-result result)))
      0)))

(defun %run-deploy (arguments directory stream)
  (multiple-value-bind (branch worktree-path)
      (%parse-deploy-arguments arguments)
    (let ((result (deploy directory
                          :branch branch
                          :worktree-path worktree-path)))
      (format stream "Deployed GAW branch ~A (~(~A~))"
              (deploy-result-branch result)
              (deploy-result-mode result))
      (when (deploy-result-worktree-path result)
        (format stream " at ~A" (deploy-result-worktree-path result)))
      (terpri stream)
      (dolist (warning (deploy-result-warnings result))
        (format stream "warning: ~A~%" warning))
      0)))

(defun %run-branch (arguments directory stream)
  (unless (and (= 2 (length arguments))
               (member (first arguments) '("-m" "-d") :test #'string=))
    (%cli-error "Usage: git gaw branch -m <new-name> | -d <name>"))
  (let ((operation (first arguments))
        (name (second arguments)))
    (if (string= operation "-m")
        (progn
          (rename-branch directory name)
          (format stream "Renamed GAW branch to ~A.~%" name))
        (progn
          (delete-branch directory name)
          (format stream "Deleted GAW branch ~A.~%" name))))
  0)

(defun %run-reference-transaction (arguments directory)
  (unless (and arguments
               (null (rest arguments)))
    (%cli-error
     "git-gaw --reference-transaction requires exactly one phase"))
  (handler-case
      (progn
        (reference-transaction (first arguments)
                               directory
                               *standard-input*)
        0)
    (hook-error (condition)
      (format *error-output*
              "git-gaw: ~A~%"
              condition)
      1)))

(defun %run-version (arguments stream)
  (when arguments
    (%cli-error "git gaw version does not accept arguments"))
  (format stream
          "git-gaw ~A~%"
          (%version))
  0)

(defun %run-help (arguments stream)
  (cond
    ((null arguments)
     (print-help :overview stream))
    ((null (rest arguments))
     (print-help (%help-topic (first arguments)) stream))
    (t
     (%cli-error "git gaw help accepts at most one topic")))
  0)

(defun %dispatch (arguments directory output-stream)
  (cond
    ((and arguments
          (string= (first arguments) "--reference-transaction"))
     (%run-reference-transaction (rest arguments) directory))
    ((and arguments
          (or (string= (first arguments) "--version")
              (string= (first arguments) "version")))
     (%run-version (rest arguments) output-stream))
    ((or (equal arguments '("--help"))
         (equal arguments '("-h")))
     (%run-help '() output-stream))
    ((and arguments (string= (first arguments) "help"))
     (%run-help (rest arguments) output-stream))
    ((and arguments (string= (first arguments) "commit"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :commit output-stream) 0)
         (%run-commit (rest arguments) directory output-stream)))
    ((and arguments (string= (first arguments) "show"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :show output-stream) 0)
         (%run-show (rest arguments) directory)))
    ((and arguments (string= (first arguments) "check"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :check output-stream) 0)
         (%run-check (rest arguments) directory output-stream)))
    ((and arguments (string= (first arguments) "status"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :status output-stream) 0)
         (%run-status (rest arguments) directory output-stream)))
    ((and arguments (string= (first arguments) "deploy"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :deploy output-stream) 0)
         (%run-deploy (rest arguments) directory output-stream)))
    ((and arguments (string= (first arguments) "init"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :init output-stream) 0)
         (%run-init (rest arguments) directory output-stream)))
    ((and arguments (string= (first arguments) "branch"))
     (if (%sole-help-option-p (rest arguments))
         (progn (print-help :branch output-stream) 0)
         (%run-branch (rest arguments) directory output-stream)))
    (t
     (%usage-error))))

(defun %main-status ()
  (handler-case
      (%dispatch (uiop:command-line-arguments)
                 (uiop:getcwd)
                 *standard-output*)
    (error (condition)
      (format *error-output*
              "git-gaw: ~A~%"
              condition)
      1)))
