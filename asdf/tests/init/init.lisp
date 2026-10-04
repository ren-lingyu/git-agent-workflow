(in-package #:git-agent-workflow/tests.init)

(defun %init-git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %init-error-reason (thunk)
  (handler-case (progn (funcall thunk) nil)
    (init-error (condition) (init-error-reason condition))))

(defun %test-repository-only-init ()
  (with-test-repository (directory)
    (let* ((result (initialize directory :branch "gaw"))
           (commit (init-result-commit-oid result)))
      (assert (string= commit
                       (%init-git directory "rev-parse" "refs/heads/gaw")))
      (assert (string= "refs/heads/gaw" (current-ref directory)))
      (assert (string= "" (%init-git directory "for-each-ref"
                                   "--format=%(refname)"
                                   "refs/gaw/heads/")))
      (assert (string= "Git Agent Workflow <gaw@invalid>"
                       (%init-git directory "show" "-s"
                                  "--format=%an <%ae>" commit)))
      (assert (string= "Initialize GAW"
                       (%init-git directory "show" "-s" "--format=%s"
                                  commit))))))

(defun %test-init-refuses-existing-history ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (assert (eq :already-initialized
                (%init-error-reason
                 (lambda () (initialize directory :branch "other")))))))

(defun %test-init-preflights-worktree-conflict ()
  (with-test-repository (directory)
    (assert (eq :worktree-conflict
                (%init-error-reason
                 (lambda ()
                   (initialize directory :branch "gaw"
                               :worktree-path (namestring directory))))))
    (assert (null (protocol-refs directory)))
    (assert (string= ""
                     (%init-git directory "for-each-ref"
                                "--format=%(refname)" "refs/heads/gaw")))))

(defun %test-init-with-worktree ()
  (with-temporary-directory (outer)
    (let ((repository (merge-pathnames "repository/" outer))
          (worktree (merge-pathnames "agent/" outer)))
      (call-git (list "init" "--quiet" (namestring repository)))
      (initialize repository :branch "gaw"
                  :worktree-path (namestring worktree))
      (assert (check-report-ok-p (check worktree))))))

(defun %test-deploy-failure-removes-initial-ref-graph ()
  (with-test-repository (directory)
    (let* ((symbol 'git-agent-workflow.deploy:deploy)
           (original (symbol-function symbol)))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (error "injected deploy failure")))
             (assert (eq :deployment-failed
                         (%init-error-reason
                          (lambda ()
                            (initialize directory :branch "gaw")))))
             (assert (null (protocol-refs directory)))
             (assert (string= ""
                              (%init-git directory "for-each-ref"
                                         "--format=%(refname)"
                                         "refs/heads/gaw"))))
        (setf (symbol-function symbol) original)))))

(defun run-tests ()
  (%test-repository-only-init)
  (%test-init-refuses-existing-history)
  (%test-init-preflights-worktree-conflict)
  (%test-init-with-worktree)
  (%test-deploy-failure-removes-initial-ref-graph)
  (format t "~&All init tests passed.~%")
  t)
