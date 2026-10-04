(in-package #:git-agent-workflow/tests.state)

(defun %state-git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %state-write (directory path text)
  (write-test-octets
   (merge-pathnames path directory)
   (string-to-octets text :encoding :utf-8)))

(defun %state-initialize (directory)
  (%state-write directory ".gaw/config" "(:workspace ())")
  (%state-git directory "add" "--" ".gaw/config")
  (let* ((tree (%state-git directory "write-tree"))
         (commit (%state-git directory
                             "-c" "user.name=GAW Test"
                             "-c" "user.email=gaw-test@example.invalid"
                             "commit-tree" tree "-m" "initial")))
    (%state-git directory "update-ref" "refs/heads/gaw" commit)
    commit))

(defun %test-valid-committed-state ()
  (with-test-repository (directory)
    (%state-initialize directory)
    (let ((report (inspect-committed-state directory "refs/heads/gaw")))
      (assert (committed-state-report-ok-p report))
      (dolist (name '(:head :head-config :head-workspace :project-parents))
        (assert (eq :ok
                    (committed-state-finding-status
                     (committed-state-finding report name))))))))

(defun %test-missing-and-invalid-state ()
  (with-test-repository (directory)
    (let ((report (inspect-committed-state directory "refs/heads/missing")))
      (assert (not (committed-state-report-ok-p report)))
      (assert (eq :error
                  (committed-state-finding-status
                   (committed-state-finding report :head))))))
  (with-test-repository (directory)
    (%state-write directory ".gaw/config" "(:workspace (")
    (%state-git directory "add" "--" ".gaw/config")
    (let* ((tree (%state-git directory "write-tree"))
           (commit (%state-git directory
                               "-c" "user.name=GAW Test"
                               "-c" "user.email=gaw-test@example.invalid"
                               "commit-tree" tree "-m" "invalid")))
      (%state-git directory "update-ref" "refs/heads/gaw" commit))
    (let ((report (inspect-committed-state directory "refs/heads/gaw")))
      (assert (not (committed-state-report-ok-p report)))
      (assert (eq :error
                  (committed-state-finding-status
                   (committed-state-finding report :head-config)))))))

(defun run-tests ()
  (%test-valid-committed-state)
  (%test-missing-and-invalid-state)
  (format t "~&All state tests passed.~%")
  t)
