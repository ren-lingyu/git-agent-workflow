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

(defun %run-cli-tests ()
  (%test-message-fragments-follow-commit-tree-semantics)
  (%test-commit-argument-parser)
  (format t
          "~&All CLI tests passed.~%")
  t)
