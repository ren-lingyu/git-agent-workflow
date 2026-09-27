(in-package #:git-agent-workflow/tests.git)

(defun %call-with-temporary-directory (function)
  (let ((directory (uiop:merge-pathnames* (format nil
                                                  "git-agent-workflow test ~36R-~36R/"
                                                  (get-universal-time)
                                                  (random most-positive-fixnum))
                                          (uiop:temporary-directory))))
    (ensure-directories-exist (merge-pathnames "placeholder"
                                               directory))
    (unwind-protect (funcall function
                             directory)
      (uiop:delete-directory-tree directory
                                  :validate t
                                  :if-does-not-exist :ignore))))

(defun %initialize-git-repository (directory)
  (uiop:run-program (list "git"
                          "init"
                          "--quiet"
                          (namestring directory))
                    :output '(:string :stripped t)
                    :error-output '(:string :stripped t)
                    :force-shell nil))

(defun %test-run-git-returns-git-invocation ()
  (%call-with-temporary-directory (lambda (directory)
                                    (assert (typep (run-git '("--version")
                                                            directory)
                                                   'git-invocation)))))

(defun %test-run-git-preserves-arguments ()
  (%call-with-temporary-directory (lambda (directory)
                                    (let* ((arguments '("--version"))
                                           (invocation (run-git arguments
                                                                directory)))
                                      (assert (equal arguments
                                                     (git-invocation-arguments invocation)))))))

(defun %test-run-git-preserves-directory ()
  (%call-with-temporary-directory (lambda (directory)
                                    (let ((invocation (run-git '("--version")
                                                               directory)))
                                      (assert (equal directory
                                                     (git-invocation-directory invocation)))))))

(defun %test-run-git-constructs-command ()
  (%call-with-temporary-directory (lambda (directory)
                                    (let ((invocation (run-git '("--version")
                                                               directory)))
                                      (assert (equal (list "git"
                                                           "-C"
                                                           (namestring directory)
                                                           "--version")
                                                     (git-invocation-command invocation)))))))

(defun %test-run-git-strips-output ()
  (%call-with-temporary-directory (lambda (directory)
                                    (let* ((invocation (run-git '("--version")
                                                                directory))
                                           (stdout (git-invocation-stdout invocation)))
                                      (assert (and (plusp (length stdout))
                                                   (not (member (char stdout
                                                                      (1- (length stdout)))
                                                                '(#\Newline #\Return)))))))))

(defun %test-run-git-uses-directory ()
  (%call-with-temporary-directory (lambda (directory)
                                    (%initialize-git-repository directory)

                                    (let ((invocation (run-git '("rev-parse"
                                                                 "--is-inside-work-tree")
                                                               directory)))
                                      (assert (string= "true"
                                                       (git-invocation-stdout invocation)))))))

(defun %test-run-git-retains-failed-operation ()
  (%call-with-temporary-directory (lambda (directory)
                                    (%initialize-git-repository directory)

                                    (let ((invocation (run-git
                                                       '("rev-parse"
                                                         "--verify"
                                                         "refs/gaw/definitely-missing")
                                                       directory)))
                                      (assert (not (zerop (git-invocation-exit-status invocation))))))))

(defun %test-run-git-copies-arguments ()
  (%call-with-temporary-directory (lambda (directory)
                                    (let* ((arguments (list "--version"))
                                           (invocation (run-git arguments
                                                                directory)))
                                      (setf (car arguments)
                                            "status")
                                      (assert (equal '("--version")
                                                     (git-invocation-arguments invocation)))))))

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
