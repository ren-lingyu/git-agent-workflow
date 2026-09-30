(in-package #:git-agent-workflow.cli)

(defun %cli-error (control &rest arguments)
  (error (apply #'format
                nil
                control
                arguments)))

(defun %version ()
  (load-time-value
   (or (asdf:component-version
        (asdf:find-system "git-agent-workflow"))
       (error "The git-agent-workflow system has no version"))
   t))

(defun %option-value (argument long-name short-name arguments)
  (cond
    ((or (string= argument long-name)
         (string= argument short-name))
     (unless arguments
       (%cli-error "Option ~A requires a value"
                   argument))
     (values (first arguments)
             (rest arguments)))
    ((and (> (length argument)
             (length short-name))
          (string= short-name
                   argument
                   :end2 (length short-name)))
     (values (subseq argument
                     (length short-name))
             arguments))
    ((let ((prefix (concatenate 'string
                                long-name
                                "=")))
       (and (>= (length argument)
                (length prefix))
            (string= prefix
                     argument
                     :end2 (length prefix))))
     (values (subseq argument
                     (1+ (length long-name)))
             arguments))
    (t
     (values nil arguments))))

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
        do (vector-push-extend octet
                               buffer
                               4096)))

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
  (let ((fragments '())
        (project-commits '())
        (allow-empty nil)
        (allow-empty-message nil)
        (options-p t))
    (loop while arguments
          for argument = (pop arguments)
          do (cond
               ((and options-p
                     (string= argument "--"))
                (setf options-p nil))
               ((and options-p
                     (string= argument "--allow-empty"))
                (setf allow-empty t))
               ((and options-p
                     (string= argument "--allow-empty-message"))
                (setf allow-empty-message t))
               (options-p
                (multiple-value-bind (message remaining)
                    (%option-value argument
                                   "--message"
                                   "-m"
                                   arguments)
                  (if message
                      (setf arguments remaining
                            fragments
                            (nconc fragments
                                   (list (cons :message message))))
                      (multiple-value-bind (file file-remaining)
                          (%option-value argument
                                         "--file"
                                         "-F"
                                         arguments)
                        (cond
                          (file
                           (setf arguments file-remaining
                                 fragments
                                 (nconc fragments
                                        (list (cons :file file)))))
                          ((and (plusp (length argument))
                                (char= (char argument 0)
                                       #\-))
                           (%cli-error "Unsupported commit option: ~A"
                                       argument))
                          (t
                           (setf project-commits
                                 (nconc project-commits
                                        (list argument)))))))))
               (t
                (setf project-commits
                      (nconc project-commits
                             (list argument))))))
    (unless fragments
      (%cli-error "git gaw commit requires -m or -F"))
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

(defun %help-topic (name)
  (cond
    ((string= name "commit") :commit)
    ((string= name "show") :show)
    ((string= name "check") :check)
    (t (%cli-error "Unknown help topic: ~A" name))))

(defun %run-help (arguments stream)
  (cond
    ((null arguments)
     (print-help :overview stream))
    ((null (rest arguments))
     (print-help (%help-topic (first arguments)) stream))
    (t
     (%cli-error "git gaw help accepts at most one topic")))
  0)

(defun %usage-error ()
  (%cli-error
   "Usage:~%  git gaw commit [options] [--] [project-commit...]~%  git gaw show [options] [object...] [-- path...]~%  git gaw check~%  git gaw help [commit|show|check]"))

(defun %sole-help-option-p (arguments)
  (and arguments
       (null (rest arguments))
       (string= (first arguments) "--help")))

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

(defun main ()
  (uiop:quit (%main-status)))
