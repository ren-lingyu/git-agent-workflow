(in-package #:git-agent-workflow.git)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%make-git-invocation
                      %prepare-git-command))
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

(defun run-git (args directory)
  (multiple-value-bind (command arguments)
      (%prepare-git-command args
                            directory)
    (multiple-value-bind (stdout stderr exit-status)
        (uiop:run-program command
                          :output '(:string :stripped t)
                          :error-output '(:string :stripped t)
                          :ignore-error-status t
                          :force-shell nil)
      (%make-git-invocation :command command
                            :arguments arguments
                            :directory directory
                            :stdout stdout
                            :stderr stderr
                            :exit-status exit-status))))

(defun run-git-bytes (args directory)
  (multiple-value-bind (command arguments)
      (%prepare-git-command args
                            directory)
    (multiple-value-bind (stdout stderr exit-status)
        (uiop:run-program command
                          :output #'%slurp-octets
                          :error-output #'%slurp-octets
                          :element-type '(unsigned-byte 8)
                          :ignore-error-status t
                          :force-shell nil)
      (%make-git-invocation :command command
                            :arguments arguments
                            :directory directory
                            :stdout stdout
                            :stderr (%decode-git-stderr stderr)
                            :exit-status exit-status))))
