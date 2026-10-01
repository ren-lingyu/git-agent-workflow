(in-package #:git-agent-workflow/tests.git)

(defun %restore-environment-variable (name value)
  (if value
      (setf (uiop:getenv name)
            value)
      #+sbcl (uiop:symbol-call :sb-posix
                               :unsetenv
                               name)
      #-sbcl (error "Environment test cleanup requires SBCL")))

(defun %test-run-git-returns-git-invocation ()
  (with-temporary-directory (directory)
    (assert (typep (run-git '("--version")
                            directory)
                   'git-invocation))))

(defun %test-run-git-preserves-arguments ()
  (with-temporary-directory (directory)
    (let* ((arguments '("--version"))
           (invocation (run-git arguments
                                directory)))
      (assert (equal arguments
                     (git-invocation-arguments invocation))))))

(defun %test-run-git-preserves-directory ()
  (with-temporary-directory (directory)
    (let ((invocation (run-git '("--version")
                               directory)))
      (assert (equal directory
                     (git-invocation-directory invocation))))))

(defun %test-run-git-constructs-command ()
  (with-temporary-directory (directory)
    (let ((invocation (run-git '("--version")
                               directory)))
      (assert
       (equal (list "git"
                    "-C"
                    (namestring directory)
                    "--version")
              (git-invocation-command invocation))))))

(defun %test-run-git-strips-output ()
  (with-temporary-directory (directory)
    (let* ((invocation (run-git '("--version")
                                directory))
           (stdout (git-invocation-stdout invocation)))
      (assert
       (and (plusp (length stdout))
            (not (member (char stdout
                               (1- (length stdout)))
                         '(#\Newline #\Return))))))))

(defun %test-run-git-uses-directory ()
  (with-test-repository (directory)
    (let ((invocation (run-git '("rev-parse"
                                 "--is-inside-work-tree")
                               directory)))
      (assert (string= "true"
                       (git-invocation-stdout invocation))))))

(defun %test-run-git-retains-failed-operation ()
  (with-test-repository (directory)
    (let ((invocation
            (run-git '("rev-parse"
                       "--verify"
                       "refs/gaw/definitely-missing")
                     directory)))
      (assert
       (not (zerop
             (git-invocation-exit-status invocation)))))))

(defun %test-run-git-copies-arguments ()
  (with-temporary-directory (directory)
    (let* ((arguments (list "--version"))
           (invocation (run-git arguments
                                directory)))
      (setf (car arguments)
            "status")
      (assert (equal '("--version")
                     (git-invocation-arguments invocation))))))

(defun %test-run-git-bytes-preserves-exact-output ()
  (with-test-repository (directory)
    (let* ((payload (make-array 4
                                :element-type '(unsigned-byte 8)
                                :initial-contents '(65 0 255 10)))
           (input-path (merge-pathnames "binary-output"
                                        directory)))
      (write-test-octets input-path
                         payload)
      (let* ((object-id
               (call-git (list "-C"
                               (namestring directory)
                               "hash-object"
                               "-w"
                               "--"
                               "binary-output")))
             (arguments (list "cat-file"
                              "blob"
                              object-id))
             (invocation (run-git-bytes arguments
                                        directory)))
        (setf (first arguments)
              "status")
        (assert (typep invocation
                       'git-invocation))
        (assert (typep (git-invocation-stdout invocation)
                       '(vector (unsigned-byte 8))))
        (assert (equalp payload
                        (git-invocation-stdout invocation)))
        (assert (equal '("cat-file" "blob")
                       (subseq (git-invocation-arguments invocation)
                               0
                               2)))
        (assert (equal directory
                       (git-invocation-directory invocation)))
        (assert (zerop (git-invocation-exit-status invocation)))))))

(defun %test-run-git-bytes-retains-failure-metadata ()
  (with-test-repository (directory)
    (let ((invocation
            (run-git-bytes '("cat-file"
                             "blob"
                             "definitely-not-an-object")
                           directory)))
      (assert (not (zerop
                    (git-invocation-exit-status invocation))))
      (assert (stringp (git-invocation-stderr invocation)))
      (assert (plusp (length (git-invocation-stderr invocation)))))))

(defun %test-run-git-accepts-binary-input ()
  (with-test-repository (directory)
    (let* ((payload
             (make-array 4
                         :element-type '(unsigned-byte 8)
                         :initial-contents '(65 0 255 10)))
           (hash-invocation
             (run-git '("hash-object" "-w" "--stdin")
                      directory
                      :input payload))
           (object-id (git-invocation-stdout hash-invocation))
           (read-invocation
             (run-git-bytes (list "cat-file"
                                  "blob"
                                  object-id)
                            directory)))
      (assert (zerop (git-invocation-exit-status hash-invocation)))
      (assert (equalp payload
                      (git-invocation-stdout read-invocation))))))

(defun %test-run-git-removes-inherited-git-environment ()
  (with-test-repository (directory)
    (let ((original (uiop:getenv "GIT_DIR")))
      (unwind-protect
           (progn
             (setf (uiop:getenv "GIT_DIR")
                   "/definitely/not/the/test/repository")
             (let ((invocation
                     (run-git '("rev-parse" "--is-inside-work-tree")
                              directory)))
               (assert (zerop
                        (git-invocation-exit-status invocation)))
               (assert (string= "true"
                                (git-invocation-stdout invocation)))))
        (%restore-environment-variable "GIT_DIR"
                                       original)))))

(defun %test-run-git-accepts-explicit-git-environment ()
  (with-test-repository (directory)
    (let ((invocation
            (run-git '("var" "GIT_AUTHOR_IDENT")
                     directory
                     :git-environment
                     '(("GIT_AUTHOR_NAME" . "Explicit Author")
                       ("GIT_AUTHOR_EMAIL" . "author@example.invalid")
                       ("GIT_AUTHOR_DATE" . "@0 +0000")))))
      (assert (zerop (git-invocation-exit-status invocation)))
      (assert (search "Explicit Author <author@example.invalid>"
                      (git-invocation-stdout invocation))))))

(defun %test-run-git-ignores-inherited-global-config ()
  (with-test-repository (directory)
    (let* ((config-path (merge-pathnames "hostile-global-config"
                                         directory))
           (original (uiop:getenv "GIT_CONFIG_GLOBAL")))
      (write-test-octets
       config-path
       (babel:string-to-octets
        "[gaw-test]\nvalue = inherited\n"
        :encoding :utf-8))
      (unwind-protect
           (progn
             (setf (uiop:getenv "GIT_CONFIG_GLOBAL")
                   (namestring config-path))
             (let ((invocation
                     (run-git '("config" "--get" "gaw-test.value")
                              directory)))
               (assert (= 1
                          (git-invocation-exit-status invocation)))))
        (%restore-environment-variable "GIT_CONFIG_GLOBAL"
                                       original)))))

(defun %test-run-git-passthrough-retains-metadata-and-status ()
  (with-temporary-directory (directory)
    (write-test-octets (merge-pathnames "left" directory)
                       #(65))
    (write-test-octets (merge-pathnames "right" directory)
                       #(66))
    (let* ((arguments (list "diff"
                            "--quiet"
                            "--no-index"
                            "--"
                            "left"
                            "right"))
           (invocation (run-git-passthrough arguments
                                            directory)))
      (setf (first arguments)
            "status")
      (assert (typep invocation
                     'git-invocation))
      (assert (equal '("diff"
                       "--quiet"
                       "--no-index"
                       "--"
                       "left"
                       "right")
                     (git-invocation-arguments invocation)))
      (assert (equal directory
                     (git-invocation-directory invocation)))
      (assert (null (git-invocation-stdout invocation)))
      (assert (null (git-invocation-stderr invocation)))
      (assert (= 1
                 (git-invocation-exit-status invocation))))))

(defun %run-git-tests ()
  (%test-run-git-returns-git-invocation)
  (%test-run-git-preserves-arguments)
  (%test-run-git-preserves-directory)
  (%test-run-git-constructs-command)
  (%test-run-git-strips-output)
  (%test-run-git-uses-directory)
  (%test-run-git-retains-failed-operation)
  (%test-run-git-copies-arguments)
  (%test-run-git-bytes-preserves-exact-output)
  (%test-run-git-bytes-retains-failure-metadata)
  (%test-run-git-accepts-binary-input)
  (%test-run-git-removes-inherited-git-environment)
  (%test-run-git-accepts-explicit-git-environment)
  (%test-run-git-ignores-inherited-global-config)
  (%test-run-git-passthrough-retains-metadata-and-status)
  (format t
          "~&All Git tests passed.~%")
  t)
