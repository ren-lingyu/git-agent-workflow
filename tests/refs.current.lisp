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

(defun %run-current-ref-tests ()
  (%test-current-ref-returns-source-ref)
  (%test-current-ref-rejects-missing-head)
  (%test-current-ref-rejects-direct-head)
  (%test-current-ref-rejects-invalid-head-target)
  (%test-current-ref-rejects-missing-registration)
  (%test-current-ref-rejects-direct-registration)
  (%test-current-ref-rejects-invalid-registration-target)
  (%test-current-ref-rejects-dangling-registration)
  (format t
          "~&All current-ref tests passed.~%")
  t)
