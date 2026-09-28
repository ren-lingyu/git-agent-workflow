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

(defun run-tests ()
  (%test-run-git-returns-git-invocation)
  (%test-run-git-preserves-arguments)
  (%test-run-git-preserves-directory)
  (%test-run-git-constructs-command)
  (%test-run-git-strips-output)
  (%test-run-git-uses-directory)
  (%test-run-git-retains-failed-operation)
  (%test-run-git-copies-arguments)
  (format t
          "~&All Git tests passed.~%")
  t)
