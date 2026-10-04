(in-package #:git-agent-workflow/tests.refs)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %test-inspection-and-dangling ()
  (with-test-repository (directory)
    (assert (not (ref-state-exists-p
                  (inspect-ref "refs/gaw/HEAD" directory))))
    (%git directory "symbolic-ref" "refs/gaw/HEAD" "refs/heads/gaw")
    (let ((state (inspect-ref "refs/gaw/HEAD" directory)))
      (assert (ref-state-exists-p state))
      (assert (ref-state-symbolic-p state))
      (assert (string= "refs/heads/gaw"
                       (ref-state-symbolic-target state))))
    (assert (ref-dangling-p "refs/gaw/HEAD" directory))))

(defun %test-selection-and-rollback ()
  (with-test-repository (directory)
    (let* ((tree (%git directory "mktree"))
           (oid (%git directory "-c" "user.name=GAW Test"
                      "-c" "user.email=gaw-test@example.invalid"
                      "commit-tree" tree "-m" "source")))
      (%git directory "update-ref" "refs/heads/one" oid)
      (%git directory "update-ref" "refs/heads/two" oid)
      (let ((change (select-source-ref "refs/heads/one" directory)))
        (assert (string= "refs/heads/one" (current-ref directory)))
        (restore-source-selection change directory)
        (assert (not (ref-state-exists-p
                      (inspect-ref "refs/gaw/HEAD" directory)))))
      (select-source-ref "refs/heads/one" directory)
      (rename-selected-source "refs/heads/one" "refs/heads/two" directory)
      (assert (string= "refs/heads/two" (current-ref directory)))
      (delete-selector directory)
      (assert (not (ref-state-exists-p
                    (inspect-ref "refs/gaw/HEAD" directory)))))))

(defun %run-ref-tests ()
  (%test-inspection-and-dangling)
  (%test-selection-and-rollback)
  (format t "~&All refs tests passed.~%")
  t)
