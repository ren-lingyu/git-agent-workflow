(in-package #:git-agent-workflow/tests.refs)

(defun %create-test-commit (directory)
  (call-git (list "-C"
                  (namestring directory)
                  "-c"
                  "user.name=GAW Test"
                  "-c"
                  "user.email=gaw-test@example.invalid"
                  "commit"
                  "--allow-empty"
                  "--quiet"
                  "--no-verify"
                  "--no-gpg-sign"
                  "-m"
                  "test"))
  (call-git (list "-C"
                  (namestring directory)
                  "rev-parse"
                  "HEAD")))

(defun %create-direct-ref (checked-ref directory)
  (let ((object-id (%create-test-commit directory)))
    (call-git (list "-C"
                    (namestring directory)
                    "update-ref"
                    checked-ref
                    object-id)))
  checked-ref)

(defun %delete-direct-ref (checked-ref directory)
  (call-git (list "-C"
                  (namestring directory)
                  "update-ref"
                  "-d"
                  checked-ref))
  checked-ref)

(defun %create-symbolic-ref (target-ref source-ref directory)
  (call-git (list "-C"
                  (namestring directory)
                  "symbolic-ref"
                  target-ref
                  source-ref))
  target-ref)

(defun %read-symbolic-ref (target-ref directory)
  (call-git (list "-C"
                  (namestring directory)
                  "symbolic-ref"
                  "--quiet"
                  "--no-recurse"
                  target-ref)))

(defun %ref-exists-p (checked-ref directory)
  (multiple-value-bind (stdout stderr exit-status)
      (call-git (list "-C"
                      (namestring directory)
                      "show-ref"
                      "--exists"
                      checked-ref)
                :ignore-error-status t)
    (declare (ignore stdout
                     stderr))
    (case exit-status
      (0
       t)
      (2
       nil)
      (otherwise
       (error "Failed to check test Git ref ~S"
              checked-ref)))))

(defun %test-make-ref-maps-source-ref ()
  (assert (string= "refs/gaw/heads/test"
                   (make-ref "refs/heads/test"))))

(defun %test-make-ref-preserves-nested-name ()
  (assert (string= "refs/gaw/heads/feature/test"
                   (make-ref "refs/heads/feature/test"))))

(defun %test-make-ref-rejects-invalid-source-ref ()
  (assert (signals error
            (make-ref "refs/tags/test"))))

(defun %test-make-ref-uses-special-ref-prefixes ()
  (let ((git-agent-workflow.refs::*source-ref-prefix*
          "refs/remotes/origin/")
        (git-agent-workflow.refs::*target-ref-prefix*
          "refs/gaw/remotes/origin/"))
    (assert (string= "refs/gaw/remotes/origin/test"
                     (make-ref "refs/remotes/origin/test")))))

(defun %test-inspect-ref-detects-missing-ref ()
  (with-test-repository (directory)
    (let ((state (inspect-ref "refs/heads/missing"
                              directory)))
      (assert (string= "refs/heads/missing"
                       (ref-state-name state)))
      (assert (not (ref-state-exists-p state)))
      (assert (not (ref-state-symbolic-p state)))
      (assert (null (ref-state-symbolic-target state))))))

(defun %test-inspect-ref-detects-direct-ref ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (let ((state (inspect-ref "refs/heads/test"
                              directory)))
      (assert (ref-state-exists-p state))
      (assert (not (ref-state-symbolic-p state)))
      (assert (null (ref-state-symbolic-target state))))))

(defun %test-inspect-ref-detects-symbolic-ref ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (let ((state (inspect-ref "refs/gaw/heads/test"
                              directory)))
      (assert (ref-state-exists-p state))
      (assert (ref-state-symbolic-p state))
      (assert (string= "refs/heads/test"
                       (ref-state-symbolic-target state))))))

(defun %test-ref-dangling-p-detects-valid-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (assert (not (ref-dangling-p "refs/gaw/heads/test"
                                 directory)))))

(defun %test-ref-dangling-p-detects-missing-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (%delete-direct-ref "refs/heads/test"
                        directory)
    (assert (ref-dangling-p "refs/gaw/heads/test"
                            directory))))

(defun %test-register-ref-creates-symbolic-ref ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (assert (string= "refs/gaw/heads/test"
                     (register-ref "refs/heads/test"
                                   directory)))
    (assert (string= "refs/heads/test"
                     (%read-symbolic-ref "refs/gaw/heads/test"
                                         directory)))))

(defun %test-register-ref-rejects-existing-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/old"
                        directory)
    (%create-direct-ref "refs/heads/new"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/new"
                          "refs/heads/old"
                          directory)
    (assert (signals error
              (register-ref "refs/heads/new"
                            directory)))))

(defun %test-register-ref-overwrites-existing-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/old"
                        directory)
    (%create-direct-ref "refs/heads/new"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/new"
                          "refs/heads/old"
                          directory)
    (register-ref "refs/heads/new"
                  directory
                  :overwrite t)
    (assert (string= "refs/heads/new"
                     (%read-symbolic-ref "refs/gaw/heads/new"
                                         directory)))))

(defun %test-unregister-ref-removes-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (assert (string= "refs/gaw/heads/test"
                     (unregister-ref "refs/gaw/heads/test"
                                     directory)))
    (assert (not (%ref-exists-p "refs/gaw/heads/test"
                                directory)))))

(defun %test-unregister-ref-removes-dangling-target ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/heads/test"
                        directory)
    (%create-symbolic-ref "refs/gaw/heads/test"
                          "refs/heads/test"
                          directory)
    (%delete-direct-ref "refs/heads/test"
                        directory)
    (unregister-ref "refs/gaw/heads/test"
                    directory)
    (assert (not (%ref-exists-p "refs/gaw/heads/test"
                                directory)))))

(defun %test-unregister-ref-rejects-missing-target ()
  (with-test-repository (directory)
    (assert (signals error
              (unregister-ref "refs/gaw/heads/missing"
                              directory)))))

(defun %test-unregister-ref-rejects-direct-ref ()
  (with-test-repository (directory)
    (%create-direct-ref "refs/gaw/heads/test"
                        directory)
    (assert (signals error
              (unregister-ref "refs/gaw/heads/test"
                              directory)))))

(defun %test-unregister-ref-rejects-invalid-target-ref ()
  (with-test-repository (directory)
    (assert (signals error
              (unregister-ref "refs/heads/test"
                              directory)))))

(defun %run-ref-tests ()
  (%test-make-ref-maps-source-ref)
  (%test-make-ref-preserves-nested-name)
  (%test-make-ref-rejects-invalid-source-ref)
  (%test-make-ref-uses-special-ref-prefixes)
  (%test-inspect-ref-detects-missing-ref)
  (%test-inspect-ref-detects-direct-ref)
  (%test-inspect-ref-detects-symbolic-ref)
  (%test-ref-dangling-p-detects-valid-target)
  (%test-ref-dangling-p-detects-missing-target)
  (%test-register-ref-creates-symbolic-ref)
  (%test-register-ref-rejects-existing-target)
  (%test-register-ref-overwrites-existing-target)
  (%test-unregister-ref-removes-target)
  (%test-unregister-ref-removes-dangling-target)
  (%test-unregister-ref-rejects-missing-target)
  (%test-unregister-ref-rejects-direct-ref)
  (%test-unregister-ref-rejects-invalid-target-ref)
  (format t
          "~&All refs tests passed.~%")
  t)
