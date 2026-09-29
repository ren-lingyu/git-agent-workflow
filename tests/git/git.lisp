(in-package #:git-agent-workflow/tests.git)

(defun %test-run-git-returns-git-invocation ()
  (with-temporary-directory (directory)
    (assert (typep (run-git '("--version")
                            directory)
                   'git-invocation))))

(defun %test-run-git-preserves-arguments ()
  (with-temporary-directory (directory)
    (let* ((arguments '("--version"))
           (invocation (run-git arguments
                                directory)))
      (assert (equal arguments
                     (git-invocation-arguments invocation))))))

(defun %test-run-git-preserves-directory ()
  (with-temporary-directory (directory)
    (let ((invocation (run-git '("--version")
                               directory)))
      (assert (equal directory
                     (git-invocation-directory invocation))))))

(defun %test-run-git-constructs-command ()
  (with-temporary-directory (directory)
    (let ((invocation (run-git '("--version")
                               directory)))
      (assert
       (equal (list "git"
                    "-C"
                    (namestring directory)
                    "--version")
              (git-invocation-command invocation))))))

(defun %test-run-git-strips-output ()
  (with-temporary-directory (directory)
    (let* ((invocation (run-git '("--version")
                                directory))
           (stdout (git-invocation-stdout invocation)))
      (assert
       (and (plusp (length stdout))
            (not (member (char stdout
                               (1- (length stdout)))
                         '(#\Newline #\Return))))))))

(defun %test-run-git-uses-directory ()
  (with-test-repository (directory)
    (let ((invocation (run-git '("rev-parse"
                                 "--is-inside-work-tree")
                               directory)))
      (assert (string= "true"
                       (git-invocation-stdout invocation))))))

(defun %test-run-git-retains-failed-operation ()
  (with-test-repository (directory)
    (let ((invocation
            (run-git '("rev-parse"
                       "--verify"
                       "refs/gaw/definitely-missing")
                     directory)))
      (assert
       (not (zerop
             (git-invocation-exit-status invocation)))))))

(defun %test-run-git-copies-arguments ()
  (with-temporary-directory (directory)
    (let* ((arguments (list "--version"))
           (invocation (run-git arguments
                                directory)))
      (setf (car arguments)
            "status")
      (assert (equal '("--version")
                     (git-invocation-arguments invocation))))))

(defun %test-run-git-bytes-preserves-exact-output ()
  (with-test-repository (directory)
    (let* ((payload (make-array 4
                                :element-type '(unsigned-byte 8)
                                :initial-contents '(65 0 255 10)))
           (input-path (merge-pathnames "binary-output"
                                        directory)))
      (write-test-octets input-path
                         payload)
      (let* ((object-id
               (call-git (list "-C"
                               (namestring directory)
                               "hash-object"
                               "-w"
                               "--"
                               "binary-output")))
             (arguments (list "cat-file"
                              "blob"
                              object-id))
             (invocation (run-git-bytes arguments
                                        directory)))
        (setf (first arguments)
              "status")
        (assert (typep invocation
                       'git-invocation))
        (assert (typep (git-invocation-stdout invocation)
                       '(vector (unsigned-byte 8))))
        (assert (equalp payload
                        (git-invocation-stdout invocation)))
        (assert (equal '("cat-file" "blob")
                       (subseq (git-invocation-arguments invocation)
                               0
                               2)))
        (assert (equal directory
                       (git-invocation-directory invocation)))
        (assert (zerop (git-invocation-exit-status invocation)))))))

(defun %test-run-git-bytes-retains-failure-metadata ()
  (with-test-repository (directory)
    (let ((invocation
            (run-git-bytes '("cat-file"
                             "blob"
                             "definitely-not-an-object")
                           directory)))
      (assert (not (zerop
                    (git-invocation-exit-status invocation))))
      (assert (stringp (git-invocation-stderr invocation)))
      (assert (plusp (length (git-invocation-stderr invocation)))))))

(defun %run-git-tests ()
  (%test-run-git-returns-git-invocation)
  (%test-run-git-preserves-arguments)
  (%test-run-git-preserves-directory)
  (%test-run-git-constructs-command)
  (%test-run-git-strips-output)
  (%test-run-git-uses-directory)
  (%test-run-git-retains-failed-operation)
  (%test-run-git-copies-arguments)
  (%test-run-git-bytes-preserves-exact-output)
  (%test-run-git-bytes-retains-failure-metadata)
  (format t
          "~&All Git tests passed.~%")
  t)
