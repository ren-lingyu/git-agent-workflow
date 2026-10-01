(in-package #:git-agent-workflow/tests.deploy)

(defun %deploy-git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %write-config (directory text)
  (write-test-octets
   (merge-pathnames ".gaw/config" directory)
   (string-to-octets text :encoding :utf-8)))

(defun %make-gaw-branch
    (directory branch &optional (config (format nil "(:workspace ())~%")))
  (%write-config directory config)
  (%deploy-git directory "add" "--" ".gaw/config")
  (let* ((tree (%deploy-git directory "write-tree"))
         (commit (%deploy-git directory
                              "-c" "user.name=GAW Test"
                              "-c" "user.email=gaw-test@example.invalid"
                              "commit-tree" tree "-m" "initial")))
    (%deploy-git directory "update-ref"
                 (concatenate 'string "refs/heads/" branch) commit)
    commit))

(defun %deploy-error-reason (thunk)
  (handler-case (progn (funcall thunk) nil)
    (deploy-error (condition) (deploy-error-reason condition))))

(defun %test-explicit-repository-only-deploy ()
  (with-test-repository (directory)
    (%make-gaw-branch directory "gaw")
    (let ((result (deploy directory :branch "gaw")))
      (assert (eq :repository-only (deploy-result-mode result)))
      (assert (string= "gaw" (deploy-result-branch result)))
      (assert (null (deploy-result-worktree-path result))))
    (assert (string= "refs/heads/gaw" (current-ref directory)))
    (assert (registered-ref-p "refs/heads/gaw" directory))
    (assert (eq :canonical
                (hook-configuration-status
                 (inspect-protection-hook directory))))
    (let ((again (deploy directory :branch "gaw")))
      (assert (eq :repository-only (deploy-result-mode again))))))

(defun %test-valid-head-is-a-fast-path ()
  (with-test-repository (directory)
    (%make-gaw-branch directory "gaw")
    (%make-gaw-branch directory "broken" "(:workspace (")
    (deploy directory :branch "gaw")
    (let ((result (deploy directory)))
      (assert (string= "gaw" (deploy-result-branch result)))
      (assert (null (deploy-result-warnings result))))))

(defun %test-automatic-discovery-and-invalid-marker-warning ()
  (with-test-repository (directory)
    (%make-gaw-branch directory "gaw")
    (%make-gaw-branch directory "broken" "(:workspace (")
    (let ((result (deploy directory)))
      (assert (string= "gaw" (deploy-result-branch result)))
      (assert (= 1 (length (deploy-result-warnings result)))))))

(defun %test-ambiguous-and-missing-discovery ()
  (with-test-repository (directory)
    (assert (eq :no-candidate
                (%deploy-error-reason (lambda () (deploy directory))))))
  (with-test-repository (directory)
    (%make-gaw-branch directory "one")
    (%make-gaw-branch directory "two")
    (assert (eq :ambiguous-branch
                (%deploy-error-reason (lambda () (deploy directory)))))))

(defun %test-malformed-registration-blocks-discovery ()
  (with-test-repository (directory)
    (let ((commit (%make-gaw-branch directory "gaw")))
      (%deploy-git directory "update-ref" "refs/gaw/heads/gaw" commit))
    (assert (eq :corrupt-metadata
                (%deploy-error-reason (lambda () (deploy directory)))))))

(defun %test-explicit-branch-does-not-repair-registration ()
  (with-test-repository (directory)
    (let ((commit (%make-gaw-branch directory "gaw")))
      (%deploy-git directory "update-ref" "refs/gaw/heads/gaw" commit))
    (assert (eq :corrupt-metadata
                (%deploy-error-reason
                 (lambda () (deploy directory :branch "gaw")))))))

(defun %test-remote-tracking-branch-is-not-a-candidate ()
  (with-test-repository (directory)
    (let ((commit (%make-gaw-branch directory "gaw")))
      (%deploy-git directory "update-ref" "refs/remotes/origin/gaw" commit)
      (%deploy-git directory "update-ref" "-d" "refs/heads/gaw"))
    (assert (eq :no-candidate
                (%deploy-error-reason (lambda () (deploy directory)))))))

(defun %test-explicit-worktree-deploy ()
  (with-temporary-directory (outer)
    (let ((repository (merge-pathnames "repository/" outer))
          (worktree (merge-pathnames "agent/" outer)))
      (call-git (list "init" "--quiet" (namestring repository)))
      (%make-gaw-branch repository "gaw")
      (deploy repository :branch "gaw")
      (assert (eq :canonical
                  (hook-configuration-status
                   (inspect-protection-hook repository))))
      (%deploy-git repository
                   "config" "--local"
                   "hook.gaw-test-observer.event"
                   "reference-transaction")
      (%deploy-git repository
                   "config" "--local"
                   "hook.gaw-test-observer.command"
                   "touch deploy-observer-ran")
      (let ((result (deploy repository
                            :branch "gaw"
                            :worktree-path (namestring worktree))))
        (assert (eq :created-worktree (deploy-result-mode result)))
        (assert (check-report-ok-p (check worktree))))
      (assert (probe-file
               (merge-pathnames "deploy-observer-ran" repository)))
      (assert (eq :existing-worktree
                  (deploy-result-mode
                   (deploy repository :branch "gaw"
                           :worktree-path (namestring worktree))))))))

(defun %test-worktree-deploy-compensates-after-check-failure ()
  (with-temporary-directory (outer)
    (let ((repository (merge-pathnames "repository/" outer))
          (worktree (merge-pathnames "agent/" outer)))
      (call-git (list "init" "--quiet" (namestring repository)))
      (%make-gaw-branch repository "gaw")
      (deploy repository :branch "gaw")
      (%deploy-git repository
                   "config" "--local"
                   "hook.gaw-test-break-check.event"
                   "post-checkout")
      (%deploy-git
       repository
       "config" "--local"
       "hook.gaw-test-break-check.command"
       "sh -c 'git rev-parse HEAD > \"$(git rev-parse --git-path MERGE_HEAD)\"'")
      (assert
       (eq :invalid-worktree
           (%deploy-error-reason
            (lambda ()
              (deploy repository
                      :branch "gaw"
                      :worktree-path (namestring worktree))))))
      (assert (not (probe-file worktree)))
      (assert
       (not (search (namestring worktree)
                    (%deploy-git repository
                                 "worktree" "list" "--porcelain")))))))

(defun run-tests ()
  (%test-explicit-repository-only-deploy)
  (%test-valid-head-is-a-fast-path)
  (%test-automatic-discovery-and-invalid-marker-warning)
  (%test-ambiguous-and-missing-discovery)
  (%test-malformed-registration-blocks-discovery)
  (%test-explicit-branch-does-not-repair-registration)
  (%test-remote-tracking-branch-is-not-a-candidate)
  (%test-explicit-worktree-deploy)
  (%test-worktree-deploy-compensates-after-check-failure)
  (format t "~&All deploy tests passed.~%")
  t)
