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
      (assert (eq :selected-branch
                  (%branch-error-reason
                   (lambda () (delete-branch directory "gaw")))))
      (assert (string= "refs/heads/gaw" (current-ref directory)))
      (delete-branch directory "other")
      (assert (not (ref-state-exists-p
                    (inspect-ref "refs/heads/other" directory)))))))

(defun run-tests ()
  (%test-rename-preserves-native-and-selector-state)
  (%test-rename-selector-failure-is-compensated)
  (%test-delete-selected-is-rejected-and-unselected-is-safe)
  (format t "~&All branch tests passed.~%")
  t)
