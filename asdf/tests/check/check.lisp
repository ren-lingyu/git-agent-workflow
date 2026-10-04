(in-package #:git-agent-workflow/tests.check)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %git-input (directory input &rest arguments)
  (uiop:run-program
   (append (list "git" "-C" (namestring directory)) arguments)
   :input (lambda (stream)
            (write-string input stream))
   :output '(:string :stripped t)
   :error-output '(:string :stripped t)
   :force-shell nil))

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
    (%git directory "symbolic-ref" "refs/gaw/HEAD" "refs/heads/gaw")
    commit))

(defun %finding (report name)
  (find name (check-report-findings report)
        :key #'check-finding-name))

(defun %finding-status (report name)
  (let ((finding (%finding report name)))
    (and finding (check-finding-status finding))))

(defun %finding-detail (report name)
  (let ((finding (%finding report name)))
    (and finding (check-finding-detail finding))))

(defun %repository-state (directory)
  (list (%git directory "symbolic-ref" "HEAD")
        (%git directory "rev-parse" "HEAD")
        (%git directory "ls-files" "--stage" "-z")
        (%git directory
              "for-each-ref"
              "--format=%(refname)%00%(objectname)%00%(symref)"
              "refs/heads/"
              "refs/gaw/")
        (%git directory "count-objects" "-v")))

(defun %with-repository (function)
  (with-test-repository (directory)
    (%initialize directory)
    (funcall function directory)))

(defun %test-healthy-and-nested-check ()
  (%with-repository
   (lambda (directory)
     (%git directory "config" "--local" "--unset-all" "user.name")
     (%git directory "config" "--local" "--unset-all" "user.email")
     (let* ((before (%repository-state directory))
            (report (check directory))
            (after (%repository-state directory)))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :index)))
       (assert (eq :warning (%finding-status report :protection-hook)))
       (assert (null (%finding-status report :identity)))
       (assert (equal before after)))
     (let ((nested (merge-pathnames "notes/" directory)))
       (ensure-directories-exist (merge-pathnames "placeholder" nested))
       (let ((report (check nested)))
         (assert (check-report-ok-p report))
         (assert (eq :warning (%finding-status report :worktree)))
         (assert (equal (namestring directory)
                        (namestring (check-report-root report)))))))))

(defun %test-protection-hook-finding ()
  (%with-repository
   (lambda (directory)
     (%git directory "config" "--local"
           "hook.gaw-reference-transaction.command"
           "git-gaw --reference-transaction")
     (%git directory "config" "--local"
           "hook.gaw-reference-transaction.event"
           "reference-transaction")
     (%git directory "config" "--local"
           "hook.gaw-reference-transaction.enabled"
           "true")
     (let ((report (check directory)))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :protection-hook)))))))

(defun %test-missing-selector-is-warning ()
  (%with-repository
   (lambda (directory)
     (%git directory "symbolic-ref" "--delete" "refs/gaw/HEAD")
     (let ((report (check directory)))
       (assert (check-report-ok-p report))
       (assert (eq :warning (%finding-status report :selector)))
       (assert (eq :ok (%finding-status report :head)))))))

(defun %test-index-failure-and-aggregation ()
  (%with-repository
   (lambda (directory)
     (%write directory "outside" "outside")
     (%git directory "add" "--" "outside")
     (%git directory "symbolic-ref" "refs/gaw/HEAD" "refs/heads/missing")
     (%write directory ".git/MERGE_HEAD" "state")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :selector)))
       (assert (eq :error (%finding-status report :index)))
       (assert (eq :error (%finding-status report :operation-state)))
       (assert (search "not ready"
                       (with-output-to-string (stream)
                         (write-check-report report stream))))))))

(defun %test-head-and-selector-failures ()
  (%with-repository
   (lambda (directory)
     (%git directory "checkout" "--quiet" "--detach" "HEAD")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :branch)))
       (assert (eq :ok (%finding-status report :selector)))
       (assert (eq :skipped (%finding-status report :head))))))
  (with-test-repository (directory)
    (%git directory "symbolic-ref" "HEAD" "refs/heads/gaw")
    (%git directory
          "symbolic-ref"
          "refs/gaw/HEAD"
          "refs/heads/gaw")
    (let ((report (check directory)))
      (assert (not (check-report-ok-p report)))
      (assert (eq :ok (%finding-status report :branch)))
      (assert (eq :error (%finding-status report :selector)))
      (assert (eq :error (%finding-status report :head)))
      (assert (eq :skipped (%finding-status report :head-config)))))
  (%with-repository
   (lambda (directory)
     (%git directory
           "symbolic-ref"
           "refs/gaw/HEAD"
           "refs/heads/other")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :selector)))
       (assert (search "Invalid"
                       (%finding-detail report :selector)))))))

(defun %test-staged-config-variants ()
  (%with-repository
   (lambda (directory)
     (%write directory
             ".gaw/config"
             "(:workspace ((:file \"TASKS.md\")))")
     (%write directory "TASKS.md" "tasks")
     (%git directory "rm" "--cached" "--quiet" "AGENTS.md")
     (%git directory "add" "--" ".gaw/config" "TASKS.md")
     (let ((report (check directory)))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :index))))))
  (%with-repository
   (lambda (directory)
     (%git directory "rm" "--cached" "--quiet" "AGENTS.md")
     (let ((report (check directory)))
       (assert (check-report-ok-p report))
       (assert (eq :ok (%finding-status report :index))))))
  (%with-repository
   (lambda (directory)
     (%git directory "rm" "--cached" "--quiet" ".gaw/config")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :index)))
       (assert (search "no .gaw/config"
                       (%finding-detail report :index))))))
  (%with-repository
   (lambda (directory)
     (%write directory ".gaw/config" "(:workspace (")
     (%git directory "add" "--" ".gaw/config")
     (let ((report (check directory)))
       (assert (not (check-report-ok-p report)))
       (assert (eq :error (%finding-status report :index)))
       (assert (search "Invalid staged config"
                       (%finding-detail report :index)))))))

(defun %test-staged-index-shape-failures ()
  (%with-repository
   (lambda (directory)
     (%git directory
           "update-index"
           "--add"
           "--cacheinfo"
           "160000"
           (%git directory "rev-parse" "HEAD")
           "notes/submodule")
     (let ((report (check directory)))
       (assert (eq :error (%finding-status report :index)))
       (assert (search "Gitlinks"
                       (%finding-detail report :index))))))
  (%with-repository
   (lambda (directory)
     (%write directory "new" "intent")
     (%git directory "add" "-N" "--" "new")
     (let ((report (check directory)))
       (assert (eq :error (%finding-status report :index)))
       (assert (search "intent-to-add"
                       (%finding-detail report :index))))))
  (%with-repository
   (lambda (directory)
     (let ((blob (%git directory "rev-parse" "HEAD:AGENTS.md")))
       (%git directory "rm" "--cached" "--quiet" "AGENTS.md")
       (%git-input
        directory
        (format nil
                "100644 ~A 1~CAGENTS.md~%100644 ~A 2~CAGENTS.md~%"
                blob #\Tab blob #\Tab)
        "update-index"
        "--index-info"))
     (let ((report (check directory)))
       (assert (eq :error (%finding-status report :index)))
       (assert (search "unmerged"
                       (%finding-detail report :index)))))))

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
                    "CHECK-FINDING-STATUS" "CHECK-FINDING-DETAIL"
                    "CHECK-ERROR"
                    "CHECK-ERROR-REASON"))
      (multiple-value-bind (symbol status) (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun run-tests ()
  (%test-healthy-and-nested-check)
  (%test-protection-hook-finding)
  (%test-missing-selector-is-warning)
  (%test-index-failure-and-aggregation)
  (%test-head-and-selector-failures)
  (%test-staged-config-variants)
  (%test-staged-index-shape-failures)
  (%test-empty-workspace-is-valid)
  (%test-existing-project-parent-conflict)
  (%test-outside-worktree-is-a-report)
  (%test-public-package-boundary)
  (format t "~&All check tests passed.~%")
  t)
