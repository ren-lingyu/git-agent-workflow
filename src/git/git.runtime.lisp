(in-package #:git-agent-workflow.git)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%make-git-invocation
                      %prepare-git-command
                      %environment-entry-name
                      %git-environment-name-p
                      %validate-git-environment))
    (unless (fboundp function)
      (error "Required Git core function is unavailable: ~S"
               function))))

(defun %slurp-octets (stream)
  (let ((octets
          (make-array 0
                      :element-type '(unsigned-byte 8)
                      :adjustable t
                      :fill-pointer 0)))
    (loop for octet = (read-byte stream
                                nil
                                nil)
          while octet
          do (vector-push-extend octet
                                 octets
                                 4096))
    (let ((result
            (make-array (length octets)
                        :element-type '(unsigned-byte 8))))
      (replace result
               octets)
      result)))

(defun %decode-git-stderr (octets)
  (string-right-trim '(#\Newline #\Return)
                     (babel:octets-to-string octets
                                             :encoding :utf-8
                                             :errorp nil)))

(defun %decode-git-stdout (octets)
  (string-right-trim '(#\Newline #\Return)
                     (babel:octets-to-string octets
                                             :encoding :utf-8
                                             :errorp nil)))

(defun %replace-environment-entry (environment name value)
  (cons (concatenate 'string
                     name
                     "="
                     value)
        (remove name
                environment
                :test #'string=
                :key #'%environment-entry-name)))

(defun %isolated-git-environment (git-environment)
  (%validate-git-environment git-environment)
  (let ((environment
          (remove-if
           (lambda (entry)
             (let ((name (%environment-entry-name entry)))
               (or (%git-environment-name-p name)
                   (string= name "EMAIL"))))
           #+sbcl (sb-ext:posix-environ)
           #-sbcl (error "Git environment isolation requires SBCL"))))
    (dolist (binding '(("GIT_CONFIG_NOSYSTEM" . "1")
                       ("GIT_CONFIG_SYSTEM" . "/dev/null")
                       ("GIT_CONFIG_GLOBAL" . "/dev/null")))
      (setf environment
            (%replace-environment-entry environment
                                        (car binding)
                                        (cdr binding))))
    (dolist (binding git-environment)
      (setf environment
            (%replace-environment-entry environment
                                        (car binding)
                                        (cdr binding))))
    environment))

(defun %git-input-processor (input)
  (when input
    (unless (typep input
                   '(vector (unsigned-byte 8)))
      (error 'type-error
             :datum input
             :expected-type '(vector (unsigned-byte 8))))
    (lambda (stream)
      (write-sequence input
                      stream))))

(defun %run-git-octets (args directory input git-environment)
  (multiple-value-bind (command arguments)
      (%prepare-git-command args
                            directory)
    (multiple-value-bind (stdout stderr exit-status)
        (uiop:run-program command
                          :input (%git-input-processor input)
                          :output #'%slurp-octets
                          :error-output #'%slurp-octets
                          :element-type '(unsigned-byte 8)
                          :environment
                          (%isolated-git-environment git-environment)
                          :ignore-error-status t
                          :force-shell nil)
      (values command
              arguments
              stdout
              stderr
              exit-status))))

(defun run-git (args directory &key input git-environment)
  (multiple-value-bind (command arguments stdout stderr exit-status)
      (%run-git-octets args
                       directory
                       input
                       git-environment)
    (%make-git-invocation :command command
                          :arguments arguments
                          :directory directory
                          :stdout (%decode-git-stdout stdout)
                          :stderr (%decode-git-stderr stderr)
                          :exit-status exit-status)))

(defun run-git-bytes (args directory &key input git-environment)
  (multiple-value-bind (command arguments stdout stderr exit-status)
      (%run-git-octets args
                       directory
                       input
                       git-environment)
    (%make-git-invocation :command command
                          :arguments arguments
                          :directory directory
                          :stdout stdout
                          :stderr (%decode-git-stderr stderr)
                          :exit-status exit-status)))
