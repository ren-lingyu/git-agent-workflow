(in-package #:git-agent-workflow/tests.cli)

(defun %test-message-fragments-follow-commit-tree-semantics ()
  (with-temporary-directory (directory)
    (let ((file (merge-pathnames "message"
                                 directory)))
      (write-test-octets file
                         (make-array 2
                                     :element-type '(unsigned-byte 8)
                                     :initial-contents '(66 0)))
      (assert
       (equalp
        (make-array 8
                    :element-type '(unsigned-byte 8)
                    :initial-contents '(65 10 10 66 0 10 67 10))
        (git-agent-workflow.cli::%message-from-fragments
         (list (cons :message "A")
               (cons :file (namestring file))
               (cons :message "C"))))))))

(defun %test-commit-argument-parser ()
  (multiple-value-bind (message parents allow-empty allow-empty-message)
      (git-agent-workflow.cli::%parse-commit-arguments
       '("-mone" "--allow-empty" "parent" "--" "-parent"))
    (assert (equalp #(111 110 101 10)
                    message))
    (assert (equal '("parent" "-parent")
                   parents))
    (assert allow-empty)
    (assert (not allow-empty-message))))

(defun %dispatch-output (arguments directory)
  (let ((status nil))
    (values
     (with-output-to-string (stream)
       (setf status
             (git-agent-workflow.cli::%dispatch arguments directory stream)))
     status)))

(defun %test-help-dispatch ()
  (with-temporary-directory (directory)
    (multiple-value-bind (overview status)
        (%dispatch-output '("help") directory)
      (assert (zerop status))
      (assert (string= overview
                       (nth-value 0 (%dispatch-output '("--help") directory))))
      (assert (string= overview
                       (nth-value 0 (%dispatch-output '("-h") directory)))))
    (dolist (command '("commit" "show" "check"))
      (let ((topic (nth-value 0
                             (%dispatch-output (list "help" command)
                                               directory)))
            (option (nth-value 0
                              (%dispatch-output (list command "--help")
                                                directory))))
        (assert (string= topic option))))
    (assert (handler-case
                (progn
                  (%dispatch-output '("help" "config") directory)
                  nil)
              (error () t)))))

(defun %test-check-dispatch ()
  (with-temporary-directory (directory)
    (multiple-value-bind (output status)
        (%dispatch-output '("check") directory)
      (assert (= status 1))
      (assert (search "GAW worktree is not ready" output)))))

(defun %run-cli-tests ()
  (%test-message-fragments-follow-commit-tree-semantics)
  (%test-commit-argument-parser)
  (%test-help-dispatch)
  (%test-check-dispatch)
  (format t
          "~&All CLI tests passed.~%")
  t)
