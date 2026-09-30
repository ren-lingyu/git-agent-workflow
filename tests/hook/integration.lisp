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
                   "refs/gaw/heads/gaw"
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
                   "HEAD")
  (%repository-git directory
                   "symbolic-ref"
                   (format nil
                           "refs/gaw/heads/~A"
                           branch)
                   (format nil
                           "refs/heads/~A"
                           branch)))

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

(defun %test-protection-allows-unregistered-and-gaw-refs ()
  (%with-protected-repository (directory)
    (%repository-git directory
                     "branch"
                     "free"
                     "HEAD")
    (let ((before (%repository-git directory
                                   "rev-parse"
                                   "refs/heads/free"))
          (target (%repository-git directory
                                   "rev-parse"
                                   "HEAD^")))
      (%repository-git directory
                       "update-ref"
                       "refs/heads/free"
                       target
                       before)
      (assert (string= target
                       (%repository-git directory
                                        "rev-parse"
                                        "refs/heads/free"))))
    (%repository-git directory
                     "update-ref"
                     "refs/gaw/unprotected"
                     "HEAD")
    (assert (stringp
             (%repository-git directory
                              "show-ref"
                              "--verify"
                              "refs/gaw/unprotected")))))

(defun %test-protection-distinguishes-symbolic-updates ()
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
    (%repository-git directory
                     "symbolic-ref"
                     "refs/gaw/heads/gaw"
                     "refs/heads/other")
    (assert (string= "refs/heads/other"
                     (%repository-git directory
                                      "symbolic-ref"
                                      "refs/gaw/heads/gaw")))))

(defun %test-protection-rejects-dereferenced-registration-update ()
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
                     "refs/gaw/heads/gaw"
                     target
                     before))))
      (%assert-ref-unchanged directory
                             "refs/heads/gaw"
                             before))))

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

(defun %run-hook-integration-tests ()
  (%test-protection-rejects-ordinary-commit)
  (%test-protection-rejects-reset-and-update-ref)
  (%test-protection-rejects-branch-changes)
  (%test-protection-rejects-mixed-transaction)
  (%test-protection-allows-unregistered-and-gaw-refs)
  (%test-protection-distinguishes-symbolic-updates)
  (%test-protection-rejects-dereferenced-registration-update)
  (%test-gaw-commit-bypasses-only-protection-hook)
  (%test-machine-option-rejects-unknown-phase)
  (format t
          "~&All hook integration tests passed.~%")
  t)
