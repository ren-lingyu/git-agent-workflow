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

(defun %test-rename-preserves-native-and-protocol-state ()
  (with-deployed-worktree (repository worktree)
    (%branch-git repository "config" "--local"
                 "branch.gaw.description" "agent history")
    (rename-branch worktree "renamed")
    (assert (not (ref-state-exists-p
                  (inspect-ref "refs/heads/gaw" repository))))
    (assert (registered-ref-p "refs/heads/renamed" repository))
    (assert (string= "refs/heads/renamed" (current-ref repository)))
    (assert (string= "refs/heads/renamed"
                     (%branch-git worktree "symbolic-ref" "HEAD")))
    (assert (string= "agent history"
                     (%branch-git repository "config" "--local" "--get"
                                  "branch.renamed.description")))))

(defun %test-rename-protocol-failure-is-compensated ()
  (with-deployed-worktree (repository worktree)
    (let* ((symbol 'git-agent-workflow.mutation:rename-ref-registration)
           (original (symbol-function symbol)))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (error "injected protocol failure")))
             (assert (eq :protocol-failure
                         (%branch-error-reason
                          (lambda () (rename-branch worktree "renamed")))))
             (assert (ref-state-exists-p
                      (inspect-ref "refs/heads/gaw" repository)))
             (assert (not (ref-state-exists-p
                           (inspect-ref "refs/heads/renamed" repository))))
             (assert (registered-ref-p "refs/heads/gaw" repository))
             (assert (string= "refs/heads/gaw" (current-ref repository))))
        (setf (symbol-function symbol) original)))))

(defun %test-delete-requires-registration-and-uses-safe-delete ()
  (with-temporary-directory (outer)
    (let ((repository (merge-pathnames "repository/" outer)))
      (call-git (list "init" "--quiet" (namestring repository)))
      (initialize repository :branch "gaw")
      (let ((commit (%branch-git repository "rev-parse" "refs/heads/gaw")))
        (%branch-git repository "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "update-ref" "refs/heads/main" commit)
        (%branch-git repository "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "symbolic-ref" "HEAD" "refs/heads/main")
        (delete-branch repository "gaw")
        (assert (not (ref-state-exists-p
                      (inspect-ref "refs/heads/gaw" repository))))
        (assert (not (ref-state-exists-p
                      (inspect-ref "refs/gaw/heads/gaw" repository))))
        (assert (not (ref-state-exists-p
                      (inspect-ref "refs/gaw/HEAD" repository))))
        (%branch-git repository "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "branch" "ordinary" commit)
        (assert (eq :unregistered
                    (%branch-error-reason
                     (lambda () (delete-branch repository "ordinary")))))
        (assert (ref-state-exists-p
                 (inspect-ref "refs/heads/ordinary" repository)))))))

(defun %test-delete-protocol-failure-is-partial ()
  (with-temporary-directory (outer)
    (let ((repository (merge-pathnames "repository/" outer)))
      (call-git (list "init" "--quiet" (namestring repository)))
      (initialize repository :branch "gaw")
      (let* ((commit (%branch-git repository "rev-parse" "refs/heads/gaw"))
             (symbol 'git-agent-workflow.mutation:remove-ref-registration)
             (original (symbol-function symbol)))
        (%branch-git repository "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "update-ref" "refs/heads/main" commit)
        (%branch-git repository "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "symbolic-ref" "HEAD" "refs/heads/main")
        (unwind-protect
             (progn
               (setf (symbol-function symbol)
                     (lambda (&rest arguments)
                       (declare (ignore arguments))
                       (error "injected protocol failure")))
               (assert (eq :partial-failure
                           (%branch-error-reason
                            (lambda () (delete-branch repository "gaw")))))
               (assert (ref-state-exists-p
                        (inspect-ref "refs/heads/gaw" repository)))
               (assert (registered-ref-p "refs/heads/gaw" repository))
               (assert (string= "refs/heads/gaw" (current-ref repository))))
          (setf (symbol-function symbol) original))))))

(defun run-tests ()
  (%test-rename-preserves-native-and-protocol-state)
  (%test-rename-protocol-failure-is-compensated)
  (%test-delete-requires-registration-and-uses-safe-delete)
  (%test-delete-protocol-failure-is-partial)
  (format t "~&All branch tests passed.~%")
  t)
