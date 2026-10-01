(in-package #:git-agent-workflow/tests.refs)

(defun %current-ref-failure-reason (directory)
  (handler-case
      (progn
        (current-ref directory)
        nil)
    (current-ref-error (condition)
      (current-ref-error-reason condition))))

(defun %test-current-ref-returns-source-ref ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/gaw/heads/test"
                          directory)
    (assert (string= "refs/heads/test"
                     (current-ref directory)))))

(defun %test-current-ref-rejects-missing-head ()
  (with-test-repository (directory)
    (assert (eq :missing-head
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-direct-head ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/gaw/HEAD"
                        directory)
    (assert (eq :direct-head
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-invalid-head-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/heads/test"
                          directory)
    (assert (eq :invalid-head-target
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-missing-registration ()
  (with-test-repository (directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/gaw/heads/missing"
                          directory)
    (assert (eq :missing-registration
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-direct-registration ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/gaw/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/gaw/heads/test"
                          directory)
    (assert (eq :direct-registration
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-invalid-registration-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/tags/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/tags/test"
                          directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/gaw/heads/test"
                          directory)
    (assert (eq :invalid-registration-target
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-rejects-dangling-registration ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (%create-symbolic-ref "refs/gaw/HEAD"
                          "refs/gaw/heads/test"
                          directory)
    (%delete-direct-ref "refs/heads/test"
                        directory)
    (assert (eq :dangling-registration
                (%current-ref-failure-reason directory)))))

(defun %test-current-ref-uses-special-refs ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/remotes/origin/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/remotes/origin/test"
                          "refs/remotes/origin/test"
                          directory)
    (%create-symbolic-ref "refs/gaw/CURRENT"
                          "refs/gaw/remotes/origin/test"
                          directory)
    (let ((git-agent-workflow.refs::*head-ref*
            "refs/gaw/CURRENT")
          (git-agent-workflow.refs::*source-ref-prefix*
            "refs/remotes/origin/")
          (git-agent-workflow.refs::*target-ref-prefix*
            "refs/gaw/remotes/origin/"))
      (assert (string= "refs/remotes/origin/test"
                       (current-ref directory))))))

(defun %test-current-ref-captures-special-display-name ()
  (with-test-repository (directory)
    (let ((condition
            (handler-case
                (let ((git-agent-workflow.refs::*display-name*
                        "Custom GAW"))
                  (current-ref directory))
              (current-ref-error (condition)
                condition))))
      (let ((git-agent-workflow.refs::*display-name*
              "Different GAW"))
        (assert (search "Custom GAW"
                        (princ-to-string condition)))
        (assert (not (search "Different GAW"
                             (princ-to-string condition))))))))

(defun %run-current-ref-tests ()
  (%test-current-ref-returns-source-ref)
  (%test-current-ref-rejects-missing-head)
  (%test-current-ref-rejects-direct-head)
  (%test-current-ref-rejects-invalid-head-target)
  (%test-current-ref-rejects-missing-registration)
  (%test-current-ref-rejects-direct-registration)
  (%test-current-ref-rejects-invalid-registration-target)
  (%test-current-ref-rejects-dangling-registration)
  (%test-current-ref-uses-special-refs)
  (%test-current-ref-captures-special-display-name)
  (format t
          "~&All current-ref tests passed.~%")
  t)
