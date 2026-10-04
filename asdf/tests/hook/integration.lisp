(in-package #:git-agent-workflow/tests.hook)

(defun %repository-git (directory &rest arguments)
  (call-git (append (list "-C"
                          (namestring directory))
                    arguments)))

(defun %repository-git-status (directory &rest arguments)
  (nth-value 2
             (call-git (append (list "-C"
                                     (namestring directory))
                               arguments)
                       :ignore-error-status t)))

(defun %repository-git-input-status (directory input &rest arguments)
  (nth-value
   2
   (uiop:run-program
    (append (list "git"
                  "-C"
                  (namestring directory))
            arguments)
    :input (lambda (stream)
             (write-string input stream))
    :output '(:string :stripped t)
    :error-output '(:string :stripped t)
    :ignore-error-status t
    :force-shell nil)))

(defun %repository-command-status (directory command)
  (nth-value
   2
   (uiop:run-program command
                     :directory directory
                     :output '(:string :stripped t)
                     :error-output '(:string :stripped t)
                     :ignore-error-status t
                     :force-shell nil)))

(defun %write-text (directory name text)
  (write-test-octets
   (merge-pathnames name directory)
   (string-to-octets text
                     :encoding :utf-8)))

(defun %initialize-protected-repository (directory)
  (%repository-git directory
                   "symbolic-ref"
                   "HEAD"
                   "refs/heads/gaw")
  (%repository-git directory
                   "config"
                   "--local"
                   "user.name"
                   "GAW Test")
  (%repository-git directory
                   "config"
                   "--local"
                   "user.email"
                   "gaw-test@example.invalid")
  (%write-text directory
               ".gaw/config"
               "(:workspace ((:file \"AGENTS.md\")))")
  (%write-text directory
               "AGENTS.md"
               "initial")
  (%repository-git directory
                   "add"
                   "--"
                   ".gaw/config"
                   "AGENTS.md")
  (%repository-git directory
                   "commit"
                   "--quiet"
                   "--no-gpg-sign"
                   "-m"
                   "initial")
  (%write-text directory
               "AGENTS.md"
               "second")
  (%repository-git directory
                   "add"
                   "--"
                   "AGENTS.md")
  (%repository-git directory
                   "commit"
                   "--quiet"
                   "--no-gpg-sign"
                   "-m"
                   "second")
  (%repository-git directory
                   "symbolic-ref"
                   "refs/gaw/HEAD"
                   "refs/heads/gaw")
  (%repository-git directory
                   "config"
                   "--local"
                   "hook.gaw-reference-transaction.event"
                   "reference-transaction")
  (%repository-git directory
                   "config"
                   "--local"
                   "hook.gaw-reference-transaction.command"
                   "git-gaw --reference-transaction"))

(defmacro %with-protected-repository ((directory) &body body)
  `(with-test-repository (,directory)
     (%initialize-protected-repository ,directory)
     ,@body))

(defun %register-branch (directory branch)
  (%repository-git directory
                   "branch"
                   branch
                   "HEAD"))

(defun %ordinary-commit (directory message)
  (let ((tree (%repository-git directory "mktree")))
    (%repository-git directory
                     "-c" "user.name=GAW Test"
                     "-c" "user.email=gaw-test@example.invalid"
                     "commit-tree" tree "-m" message)))

(defun %assert-ref-unchanged (directory ref expected)
  (assert (string= expected
                   (%repository-git directory
                                    "rev-parse"
                                    ref))))

(defun %test-protection-rejects-ordinary-commit ()
  (%with-protected-repository (directory)
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/gaw")))
      (assert (not (zerop
                    (%repository-git-status
                     directory
                     "commit"
                     "--allow-empty"
                     "--no-gpg-sign"
                     "-m"
                     "blocked"))))
      (%assert-ref-unchanged directory
                             "refs/heads/gaw"
                             before))))

(defun %test-protection-rejects-reset-and-update-ref ()
  (%with-protected-repository (directory)
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/gaw"))
          (target (%repository-git directory
                                   "rev-parse"
                                   "HEAD^")))
      (assert (not (zerop
                    (%repository-git-status directory
                                            "reset"
                                            "--hard"
                                            "HEAD^"))))
      (%assert-ref-unchanged directory
                             "refs/heads/gaw"
                             before)
      (assert (not (zerop
                    (%repository-git-status directory
                                            "update-ref"
                                            "refs/heads/gaw"
                                            target
                                            before))))
      (%assert-ref-unchanged directory
                             "refs/heads/gaw"
                             before))))

(defun %test-protection-rejects-branch-changes ()
  (%with-protected-repository (directory)
    (%register-branch directory
                      "protected")
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/protected")))
      (assert (not (zerop
                    (%repository-git-status directory
                                            "branch"
                                            "--force"
                                            "protected"
                                            "HEAD^"))))
      (%assert-ref-unchanged directory
                             "refs/heads/protected"
                             before)
      (assert (not (zerop
                    (%repository-git-status directory
                                            "branch"
                                            "--delete"
                                            "--force"
                                            "protected"))))
      (%assert-ref-unchanged directory
                             "refs/heads/protected"
                             before)
      (assert (not (zerop
                    (%repository-git-status directory
                                            "symbolic-ref"
                                            "refs/heads/protected"
                                            "refs/heads/gaw"))))
      (%assert-ref-unchanged directory
                             "refs/heads/protected"
                             before))))

(defun %test-protection-rejects-mixed-transaction ()
  (%with-protected-repository (directory)
    (%register-branch directory
                      "protected")
    (%repository-git directory
                     "branch"
                     "free"
                     "HEAD")
    (let* ((protected-before
             (%repository-git directory
                              "rev-parse"
                              "refs/heads/protected"))
           (free-before
             (%repository-git directory
                              "rev-parse"
                              "refs/heads/free"))
           (target (%repository-git directory
                                    "rev-parse"
                                    "HEAD^"))
           (input (format nil
                          "update refs/heads/protected ~A ~A~%update refs/heads/free ~A ~A~%"
                          target
                          protected-before
                          target
                          free-before)))
      (assert (not (zerop
                    (%repository-git-input-status directory
                                                  input
                                                  "update-ref"
                                                  "--stdin"))))
      (%assert-ref-unchanged directory
                             "refs/heads/protected"
                             protected-before)
      (%assert-ref-unchanged directory
                             "refs/heads/free"
                             free-before))))

(defun %test-protection-allows-ordinary-and-rejects-gaw-refs ()
  (%with-protected-repository (directory)
    (let* ((before (%ordinary-commit directory "ordinary one"))
           (target (%ordinary-commit directory "ordinary two")))
      (%repository-git directory "update-ref" "refs/heads/free" before)
      (%repository-git directory
                       "update-ref"
                       "refs/heads/free"
                       target
                       before)
      (assert (string= target
                       (%repository-git directory
                                        "rev-parse"
                                        "refs/heads/free"))))
    (assert (not (zerop
                  (%repository-git-status directory
                                          "update-ref"
                                          "refs/gaw/unprotected"
                                          "HEAD"))))))

(defun %test-protection-allows-head-switch-and-rejects-protocol-symref ()
  (%with-protected-repository (directory)
    (%repository-git directory
                     "branch"
                     "project"
                     "HEAD")
    (%repository-git directory
                     "switch"
                     "--quiet"
                     "project")
    (assert (string= "refs/heads/project"
                     (%repository-git directory
                                      "symbolic-ref"
                                      "HEAD")))
    (%repository-git directory
                     "branch"
                     "other"
                     "HEAD")
    (assert (not (zerop
                  (%repository-git-status directory
                                          "symbolic-ref"
                                          "refs/gaw/HEAD"
                                          "refs/heads/other"))))
    (assert (string= "refs/heads/gaw"
                     (%repository-git directory
                                      "symbolic-ref"
                                      "refs/gaw/HEAD")))))

(defun %test-selector-bypass-preserves-observer-hook ()
  (%with-protected-repository (directory)
    (%repository-git directory "branch" "new" "HEAD")
    (%repository-git directory
                     "config" "--local"
                     "hook.gaw-test-observer.event"
                     "reference-transaction")
    (%repository-git directory
                     "config" "--local"
                     "hook.gaw-test-observer.command"
                     "touch refs-observer-ran")
    (%repository-git directory "-c"
                     "hook.gaw-reference-transaction.enabled=false"
                     "symbolic-ref" "refs/gaw/HEAD" "refs/heads/new")
    (assert (string= "refs/heads/new"
                     (%repository-git directory
                                      "symbolic-ref"
                                      "refs/gaw/HEAD")))
    (assert (probe-file (merge-pathnames "refs-observer-ran" directory)))))

(defun %test-protection-rejects-dereferenced-selector-update ()
  (%with-protected-repository (directory)
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/gaw"))
          (target (%repository-git directory
                                   "rev-parse"
                                   "HEAD^")))
      (assert (not (zerop
                    (%repository-git-status
                     directory
                     "update-ref"
                     "refs/gaw/HEAD"
                     target
                     before))))
      (%assert-ref-unchanged directory
                             "refs/heads/gaw"
                             before))))

(defun %test-invalid-marker-branch-retains-marker-ownership ()
  (%with-protected-repository (directory)
    (%write-text directory ".gaw/config" "invalid config")
    (%repository-git directory "add" "--" ".gaw/config")
    (let* ((tree (%repository-git directory "write-tree"))
           (invalid (%repository-git directory "commit-tree" tree
                                     "-m" "invalid marker")))
      (%repository-git directory "update-ref" "refs/heads/invalid" invalid)
      (%write-text directory "AGENTS.md" "other workspace content")
      (%repository-git directory "add" "--" "AGENTS.md")
      (let* ((same-marker-tree (%repository-git directory "write-tree"))
             (same-marker (%repository-git directory "commit-tree"
                                           same-marker-tree "-m" "same marker")))
        (%repository-git directory "update-ref" "refs/heads/invalid"
                         same-marker invalid)
        (%write-text directory ".gaw/config" "different invalid config")
        (%repository-git directory "add" "--" ".gaw/config")
        (let* ((changed-tree (%repository-git directory "write-tree"))
               (changed (%repository-git directory "commit-tree"
                                         changed-tree "-m" "changed marker")))
          (assert (not (zerop
                        (%repository-git-status
                         directory "update-ref" "refs/heads/invalid"
                         changed same-marker))))
          (%assert-ref-unchanged directory "refs/heads/invalid"
                                 same-marker))))))

(defun %test-gaw-commit-bypasses-only-protection-hook ()
  (%with-protected-repository (directory)
    (%repository-git directory
                     "config"
                     "--local"
                     "hook.gaw-test-observer.event"
                     "reference-transaction")
    (%repository-git directory
                     "config"
                     "--local"
                     "hook.gaw-test-observer.command"
                     "touch configured-hook-ran")
    (%write-text directory
                 "AGENTS.md"
                 "protected update")
    (%repository-git directory
                     "add"
                     "--"
                     "AGENTS.md")
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/gaw")))
      (assert (zerop
               (%repository-command-status
                directory
                '("git" "gaw" "commit" "-m" "protected update"))))
      (assert (not (string= before
                            (%repository-git directory
                                             "rev-parse"
                                             "refs/heads/gaw"))))
      (assert (probe-file
               (merge-pathnames "configured-hook-ran"
                                directory))))))

(defun %test-machine-option-rejects-unknown-phase ()
  (with-test-repository (directory)
    (assert (not (zerop
                  (%repository-command-status
                   directory
                   '("git-gaw"
                     "--reference-transaction"
                     "future")))))))

(defun %test-protection-hook-configuration-management ()
  (with-test-repository (directory)
    (assert (eq :absent
                (hook-configuration-status
                 (inspect-protection-hook directory))))
    (assert (eq :installed (ensure-protection-hook directory)))
    (assert (eq :canonical
                (hook-configuration-status
                 (inspect-protection-hook directory))))
    (assert (eq :existing (ensure-protection-hook directory)))
    (assert (string= "true"
                     (%repository-git directory
                                      "config" "--local" "--type=bool"
                                      "--get"
                                      "hook.gaw-reference-transaction.enabled"))))
  (with-test-repository (directory)
    (%repository-git directory
                     "config" "--local"
                     "hook.gaw-reference-transaction.event"
                     "reference-transaction")
    (assert (eq :conflict
                (hook-configuration-status
                 (inspect-protection-hook directory))))
    (assert (eq :conflict
                (handler-case
                    (progn (ensure-protection-hook directory) nil)
                  (hook-configuration-error (condition)
                    (hook-configuration-error-reason condition)))))))

(defun %run-hook-integration-tests ()
  (%test-protection-rejects-ordinary-commit)
  (%test-protection-rejects-reset-and-update-ref)
  (%test-protection-rejects-branch-changes)
  (%test-protection-rejects-mixed-transaction)
  (%test-protection-allows-ordinary-and-rejects-gaw-refs)
  (%test-protection-allows-head-switch-and-rejects-protocol-symref)
  (%test-selector-bypass-preserves-observer-hook)
  (%test-protection-rejects-dereferenced-selector-update)
  (%test-invalid-marker-branch-retains-marker-ownership)
  (%test-gaw-commit-bypasses-only-protection-hook)
  (%test-machine-option-rejects-unknown-phase)
  (%test-protection-hook-configuration-management)
  (format t
          "~&All hook integration tests passed.~%")
  t)
