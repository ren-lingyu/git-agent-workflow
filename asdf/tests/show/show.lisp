(in-package #:git-agent-workflow/tests.show)

(defun %test-show-argument-policy ()
  (assert
   (equal '("show"
            "--first-parent"
            "--diff-merges=first-parent")
          (git-agent-workflow.show::%prepare-show-arguments '())))
  (assert
   (equal '("show"
            "--stat"
            "HEAD"
            "--first-parent"
            "--diff-merges=first-parent"
            "--"
            "-m")
          (git-agent-workflow.show::%prepare-show-arguments
           '("--stat" "HEAD" "--" "-m"))))
  (assert
   (equal '("show"
            "--no-diff-merges"
            "HEAD"
            "--first-parent")
          (git-agent-workflow.show::%prepare-show-arguments
           '("--no-diff-merges" "HEAD"))))
  (assert
   (equal '("show"
            "--diff-merges=off"
            "--diff-merges=first-parent"
            "HEAD"
            "--first-parent"
            "--diff-merges=first-parent")
          (git-agent-workflow.show::%prepare-show-arguments
           '("--diff-merges=off"
             "--diff-merges=first-parent"
             "HEAD"))))
  (dolist (argument '("-m"
                      "-c"
                      "--cc"
                      "--remerge-diff"
                      "--diff-merges=on"
                      "--diff-merges=m"
                      "--diff-merges=separate"
                      "--diff-merges=combined"
                      "--diff-merges=c"
                      "--diff-merges=dense-combined"
                      "--diff-merges=cc"
                      "--diff-merges=remerge"
                      "--diff-merges=r"))
    (let ((condition
            (handler-case
                (progn
                  (show #P"./"
                        (list argument "HEAD"))
                  nil)
              (show-error (condition)
                condition))))
      (assert condition)
      (assert (eq :unsupported-option
                  (show-error-reason condition)))))
  (let ((arguments (list "HEAD")))
    (git-agent-workflow.show::%prepare-show-arguments arguments)
    (assert (equal '("HEAD")
                   arguments))))

(defun %repository-git (directory &rest arguments)
  (call-git (append (list "-C"
                          (namestring directory))
                    arguments)))

(defun %write-text (directory name text)
  (write-test-octets (merge-pathnames name directory)
                     (babel:string-to-octets text
                                             :encoding :utf-8)))

(defun %create-show-history (directory)
  (%repository-git directory
                   "config"
                   "--local"
                   "user.name"
                   "GAW Show Test")
  (%repository-git directory
                   "config"
                   "--local"
                   "user.email"
                   "gaw-show@example.invalid")
  (%write-text directory
               ".gaw/config"
               "(:workspace ((:file \"AGENTS.md\")))")
  (%write-text directory
               "AGENTS.md"
               "agent-v1\n")
  (%repository-git directory
                   "add"
                   "--"
                   ".gaw/config"
                   "AGENTS.md")
  (let* ((initial-tree (%repository-git directory
                                        "write-tree"))
         (initial (%repository-git directory
                                  "commit-tree"
                                  initial-tree
                                  "-m"
                                  "initial gaw")))
    (%repository-git directory
                     "read-tree"
                     "--empty")
    (%write-text directory
                 "src/project.txt"
                 "project\n")
    (%repository-git directory
                     "add"
                     "--"
                     "src/project.txt")
    (let* ((project-tree (%repository-git directory
                                          "write-tree"))
           (project (%repository-git directory
                                     "commit-tree"
                                     project-tree
                                     "-m"
                                     "project snapshot")))
      (%repository-git directory
                       "read-tree"
                       initial-tree)
      (%write-text directory
                   "AGENTS.md"
                   "agent-v2\n")
      (%repository-git directory
                       "add"
                       "--"
                       "AGENTS.md")
      (let* ((association-tree (%repository-git directory
                                                "write-tree"))
             (association
               (%repository-git directory
                                "commit-tree"
                                association-tree
                                "-p"
                                initial
                                "-p"
                                project
                                "-m"
                                "associate project")))
        (values initial
                project
                association)))))

(defun %call-prepared-show (directory arguments)
  (call-git (append (list "-C"
                          (namestring directory))
                    (git-agent-workflow.show::%prepare-show-arguments
                     arguments))))

(defun %test-show-follows-canonical-gaw-history ()
  (with-test-repository (directory)
    (multiple-value-bind (initial project association)
        (%create-show-history directory)
      (declare (ignore project))
      (let ((output (%call-prepared-show directory
                                         (list association))))
        (assert (search "-agent-v1" output))
        (assert (search "+agent-v2" output))
        (assert (not (search ".gaw/config" output)))
        (assert (not (search "src/project.txt" output))))
      (let ((output
              (%call-prepared-show
               directory
               (list "--no-patch"
                     "--format=%s"
                     (concatenate 'string
                                  initial
                                  ".."
                                  association)))))
        (assert (search "associate project" output))
        (assert (not (search "project snapshot" output))))
      (let ((output
              (%call-prepared-show directory
                                   (list "--no-diff-merges"
                                         "--format=%s"
                                         association))))
        (assert (search "associate project" output))
        (assert (not (search "diff --git" output))))
      (let ((output
              (%call-prepared-show
               directory
               (list "--no-patch"
                     "--format=%s"
                     (concatenate 'string
                                  association
                                  "^2")))))
        (assert (search "project snapshot" output)))
      (assert
       (zerop
        (show directory
              (list "--no-patch"
                    "--format="
                    association)))))))

(defun %run-show-tests ()
  (%test-show-argument-policy)
  (%test-show-follows-canonical-gaw-history)
  (format t
          "~&All show tests passed.~%")
  t)
