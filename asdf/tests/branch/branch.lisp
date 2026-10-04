(in-package #:git-agent-workflow/tests.branch)

(defun %branch-git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %branch-error-reason (thunk)
  (handler-case (progn (funcall thunk) nil)
    (branch-error (condition) (branch-error-reason condition))))

(defmacro with-deployed-worktree ((repository worktree) &body body)
  `(with-temporary-directory (outer)
     (let ((,repository (merge-pathnames "repository/" outer))
           (,worktree (merge-pathnames "agent/" outer)))
       (call-git (list "init" "--quiet" (namestring ,repository)))
       (initialize ,repository :branch "gaw"
                   :worktree-path (namestring ,worktree))
       ,@body)))

(defun %test-rename-preserves-native-and-selector-state ()
  (with-deployed-worktree (repository worktree)
    (%branch-git repository "config" "--local"
                 "branch.gaw.description" "agent history")
    (rename-branch worktree "renamed")
    (assert (not (ref-state-exists-p
                  (inspect-ref "refs/heads/gaw" repository))))
    (assert (ref-state-exists-p
             (inspect-ref "refs/heads/renamed" repository)))
    (assert (string= "refs/heads/renamed" (current-ref repository)))
    (assert (string= "refs/heads/renamed"
                     (%branch-git worktree "symbolic-ref" "HEAD")))
    (assert (string= "agent history"
                     (%branch-git repository "config" "--local" "--get"
                                  "branch.renamed.description")))))

(defun %test-rename-selector-failure-is-compensated ()
  (with-deployed-worktree (repository worktree)
    (let* ((symbol 'git-agent-workflow.mutation:rename-selected-source)
           (original (symbol-function symbol)))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (error "injected selector failure")))
             (assert (eq :protocol-failure
                         (%branch-error-reason
                          (lambda () (rename-branch worktree "renamed")))))
             (assert (ref-state-exists-p
                      (inspect-ref "refs/heads/gaw" repository)))
             (assert (not (ref-state-exists-p
                           (inspect-ref "refs/heads/renamed" repository))))
             (assert (string= "refs/heads/gaw" (current-ref repository))))
        (setf (symbol-function symbol) original)))))

(defun %test-delete-selected-is-rejected-and-unselected-is-safe ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let ((commit (%branch-git directory "rev-parse" "refs/heads/gaw")))
      (%branch-git directory "-c"
                   "hook.gaw-reference-transaction.enabled=false"
                   "update-ref" "refs/heads/other" commit)
      (%branch-git directory "symbolic-ref" "HEAD" "refs/heads/gaw")
      (dolist (force '(nil t))
        (assert (eq :selected-branch
                    (%branch-error-reason
                     (lambda ()
                       (delete-branch directory "gaw" :force force))))))
      (assert (string= "refs/heads/gaw" (current-ref directory)))
      (delete-branch directory "other")
      (assert (not (ref-state-exists-p
                    (inspect-ref "refs/heads/other" directory)))))))

(defun %test-force-delete-skips-only-native-safe-delete ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%branch-git directory "symbolic-ref" "HEAD" "refs/heads/gaw")
    (let* ((base (%branch-git directory "rev-parse" "refs/heads/gaw"))
           (tree (%branch-git directory "rev-parse" "gaw^{tree}"))
           (divergent
             (%branch-git directory
                          "-c" "user.name=Git Agent Workflow"
                          "-c" "user.email=gaw@invalid"
                          "-c" "commit.gpgSign=false"
                          "commit-tree" tree "-p" base "-m" "divergent")))
      (%branch-git directory "update-ref" "refs/heads/other" divergent)
      (assert (eq :native-failure
                  (%branch-error-reason
                   (lambda () (delete-branch directory "other")))))
      (assert (ref-state-exists-p
               (inspect-ref "refs/heads/other" directory)))
      (delete-branch directory "other" :force t)
      (assert (not (ref-state-exists-p
                    (inspect-ref "refs/heads/other" directory)))))))

(defun %test-force-delete-retains-gaw-preflight ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let ((base (%branch-git directory "rev-parse" "refs/heads/gaw")))
      (%branch-git directory "update-ref" "refs/heads/other" base)
      (%branch-git directory "symbolic-ref" "refs/heads/alias"
                   "refs/heads/other")
      (dolist (name '("missing" "alias"))
        (dolist (force '(nil t))
          (assert (eq :missing-branch
                      (%branch-error-reason
                       (lambda ()
                         (delete-branch directory name :force force)))))))
      (%branch-git directory "read-tree" "--empty")
      (let* ((empty-tree (%branch-git directory "write-tree"))
             (ordinary
               (%branch-git directory
                            "-c" "user.name=Git Agent Workflow"
                            "-c" "user.email=gaw@invalid"
                            "-c" "commit.gpgSign=false"
                            "commit-tree" empty-tree "-m" "ordinary")))
        (%branch-git directory "update-ref" "refs/heads/ordinary" ordinary)
        (dolist (force '(nil t))
          (assert (eq :invalid-state
                      (%branch-error-reason
                       (lambda ()
                         (delete-branch directory "ordinary"
                                        :force force)))))))
      (%branch-git directory "-c"
                   "hook.gaw-reference-transaction.enabled=false"
                   "symbolic-ref" "refs/gaw/HEAD" "refs/heads/missing")
      (dolist (force '(nil t))
        (assert (eq :invalid-selector
                    (%branch-error-reason
                     (lambda ()
                       (delete-branch directory "other" :force force))))))
      (assert (ref-state-exists-p
               (inspect-ref "refs/heads/other" directory))))))

(defun %test-force-delete-respects-other-worktree ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let ((other-worktree (merge-pathnames "other-worktree/" directory))
          (base (%branch-git directory "rev-parse" "refs/heads/gaw")))
      (%branch-git directory "update-ref" "refs/heads/other" base)
      (%branch-git directory "worktree" "add" "--quiet"
                   (namestring other-worktree) "other")
      (assert (eq :native-failure
                  (%branch-error-reason
                   (lambda ()
                     (delete-branch directory "other" :force t)))))
      (assert (ref-state-exists-p
               (inspect-ref "refs/heads/other" directory))))))

(defun run-tests ()
  (%test-rename-preserves-native-and-selector-state)
  (%test-rename-selector-failure-is-compensated)
  (%test-delete-selected-is-rejected-and-unselected-is-safe)
  (%test-force-delete-skips-only-native-safe-delete)
  (%test-force-delete-retains-gaw-preflight)
  (%test-force-delete-respects-other-worktree)
  (format t "~&All branch tests passed.~%")
  t)
