(in-package #:git-agent-workflow.cli)

(defun %cli-error (control &rest arguments)
  (error (apply #'format
                nil
                control
                arguments)))

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

(defun %run-commit (arguments)
  (multiple-value-bind (message
                        project-commits
                        allow-empty
                        allow-empty-message)
      (%parse-commit-arguments arguments)
    (let ((oid (commit (uiop:getcwd)
                       message
                       :project-commits project-commits
                       :allow-empty allow-empty
                       :allow-empty-message allow-empty-message)))
      (format t "~A~%" oid)
      0)))

(defun %run-show (arguments)
  (show (uiop:getcwd)
        arguments))

(defun %usage-error ()
  (%cli-error
   "Usage:~%  git gaw commit [options] [--] [project-commit...]~%  git gaw show [options] [object...] [-- path...]"))

(defun main ()
  (handler-case
      (let ((arguments (uiop:command-line-arguments)))
        (cond
          ((and arguments
                (string= (first arguments)
                         "commit"))
           (%run-commit (rest arguments)))
          ((and arguments
                (string= (first arguments)
                         "show"))
           (%run-show (rest arguments)))
          (t
           (%usage-error))))
    (error (condition)
      (format *error-output*
              "git-gaw: ~A~%"
              condition)
      1)))
