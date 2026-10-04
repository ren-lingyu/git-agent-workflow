(in-package #:git-agent-workflow/tests.refs)

(defun %current-ref-failure-reason (directory)
  (handler-case
      (progn (current-ref directory) nil)
    (current-ref-error (condition)
      (current-ref-error-reason condition))))

(defun %run-current-ref-tests ()
  (with-test-repository (directory)
    (assert (eq :missing-head (%current-ref-failure-reason directory)))
    (call-git (list "-C" (namestring directory)
                    "symbolic-ref" "refs/gaw/HEAD" "refs/gaw/heads/gaw"))
    (assert (eq :invalid-head-target
                (%current-ref-failure-reason directory)))
    (call-git (list "-C" (namestring directory)
                    "symbolic-ref" "refs/gaw/HEAD" "refs/heads/gaw"))
    (assert (eq :missing-source (%current-ref-failure-reason directory)))
    (let* ((tree (call-git
                   (list "-C" (namestring directory) "mktree")))
           (oid (call-git
                 (list "-C" (namestring directory)
                       "-c" "user.name=GAW Test"
                       "-c" "user.email=gaw-test@example.invalid"
                       "commit-tree" tree "-m" "test"))))
      (call-git (list "-C" (namestring directory)
                      "update-ref" "refs/heads/gaw" oid)))
    (assert (string= "refs/heads/gaw" (current-ref directory))))
  (format t "~&All current-ref tests passed.~%")
  t)
