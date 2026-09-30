(in-package #:git-agent-workflow/tests.check)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %octets (text)
  (string-to-octets text :encoding :utf-8))

(defun %write (directory path text)
  (write-test-octets (merge-pathnames path directory) (%octets text)))

(defun %initialize (directory)
  (%git directory "config" "--local" "user.name" "GAW Test")
  (%git directory "config" "--local" "user.email"
        "gaw-test@example.invalid")
  (%write directory ".gaw/config"
          "(:workspace ((:file \"AGENTS.md\") (:directory \"notes\")))")
  (%write directory "AGENTS.md" "initial")
  (%git directory "add" "--" ".gaw/config" "AGENTS.md")
  (let* ((tree (%git directory "write-tree"))
         (commit (%git directory "commit-tree" tree "-m" "initial")))
    (%git directory "update-ref" "refs/heads/gaw" commit)
    (%git directory "symbolic-ref" "HEAD" "refs/heads/gaw")
    (%git directory "symbolic-ref" "refs/gaw/heads/gaw" "refs/heads/gaw")
    commit))

(defun %finding-status (report name)
  (let ((finding (find name (check-report-findings report)
                       :key #'check-finding-name)))
    (and finding (check-finding-status finding))))

(defun %with-repository (function)
  (with-test-repository (directory)
    (%initialize directory)
    (funcall function directory)))

(defun %test-healthy-and-nested-check ()
  (%with-repository
   (lambda (directory)
     (%git directory "config" "--local" "--unset-all" "user.name")
     (%git directory "config" "--local" "--unset-all" "user.email")
     (let* ((before (%git directory "count-objects" "-v"))
            (report (check directory))
            (after (%git directory "count-objects" "-v")))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :index)))
       (assert (null (%finding-status report :identity)))
       (assert (string= before after)))
     (let ((nested (merge-pathnames "notes/" directory)))
       (ensure-directories-exist (merge-pathnames "placeholder" nested))
       (let ((report (check nested)))
         (assert (check-report-ok-p report))
         (assert (eq :warning (%finding-status report :worktree)))
         (assert (equal (namestring directory)
                        (namestring (check-report-root report)))))))))

(defun %test-index-failure-and-aggregation ()
  (%with-repository
   (lambda (directory)
     (%write directory "outside" "outside")
     (%git directory "add" "--" "outside")
     (%git directory "symbolic-ref" "--delete" "refs/gaw/heads/gaw")
     (%write directory ".git/MERGE_HEAD" "state")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :registration)))
       (assert (eq :error (%finding-status report :index)))
       (assert (eq :error (%finding-status report :operation-state)))
       (assert (search "not ready"
                       (with-output-to-string (stream)
                         (write-check-report report stream))))))))

(defun %test-empty-workspace-is-valid ()
  (%with-repository
   (lambda (directory)
     (%write directory ".gaw/config" "(:workspace ())")
     (%git directory "add" "--" ".gaw/config")
     (%git directory "rm" "--cached" "--quiet" "AGENTS.md")
     (let* ((tree (%git directory "write-tree"))
            (parent (%git directory "rev-parse" "HEAD"))
            (commit (%git directory "commit-tree" tree "-p" parent
                          "-m" "empty workspace")))
       (%git directory "update-ref" "refs/heads/gaw" commit parent))
     (let ((report (check directory)))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :head-config)))
       (assert (eq :ok (%finding-status report :head-workspace)))
       (assert (eq :ok (%finding-status report :project-parents)))))))

(defun %test-existing-project-parent-conflict ()
  (%with-repository
   (lambda (directory)
     (let* ((gaw-tree (%git directory "write-tree"))
            (gaw-parent (%git directory "rev-parse" "HEAD"))
            (project nil))
       (unwind-protect
            (progn
              (%git directory "read-tree" "--empty")
              (%write directory "AGENTS.md" "project conflict")
              (%git directory "add" "--" "AGENTS.md")
              (setf project
                    (%git directory "commit-tree"
                          (%git directory "write-tree") "-m" "project")))
         (%git directory "read-tree" gaw-tree))
       (let ((associated
               (%git directory "commit-tree" gaw-tree
                     "-p" gaw-parent "-p" project "-m" "associated")))
         (%git directory "update-ref" "refs/heads/gaw" associated gaw-parent))
       (let ((report (check directory)))
         (assert (not (check-report-ok-p report)))
         (assert (eq :error (%finding-status report :project-parents))))))))

(defun %test-outside-worktree-is-a-report ()
  (with-temporary-directory (directory)
    (let ((report (check directory)))
      (assert (not (check-report-ok-p report)))
      (assert (eq :error (%finding-status report :worktree)))
      (assert (eq :skipped (%finding-status report :head))))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.check)))
    (dolist (name '("CHECK" "WRITE-CHECK-REPORT" "CHECK-REPORT"
                    "CHECK-REPORT-OK-P" "CHECK-REPORT-FINDINGS"
                    "CHECK-FINDING" "CHECK-FINDING-NAME"
                    "CHECK-FINDING-STATUS" "CHECK-ERROR"
                    "CHECK-ERROR-REASON"))
      (multiple-value-bind (symbol status) (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun run-tests ()
  (%test-healthy-and-nested-check)
  (%test-index-failure-and-aggregation)
  (%test-empty-workspace-is-valid)
  (%test-existing-project-parent-conflict)
  (%test-outside-worktree-is-a-report)
  (%test-public-package-boundary)
  (format t "~&All check tests passed.~%")
  t)
