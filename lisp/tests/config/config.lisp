(in-package #:git-agent-workflow/tests.config)

(defun %octets (text)
  (string-to-octets text
                    :encoding :utf-8))

(defun %parse-config-octets (octets)
  (git-agent-workflow.config::%config-from-octets octets
                                                  65536
                                                  16
                                                  1024
                                                  4096))

(defun %parse-config (text)
  (%parse-config-octets (%octets text)))

(defun %read-config-at-commit (commit-oid directory)
  (git-agent-workflow.config::%read-config-at-commit commit-oid
                                                      ".gaw/config"
                                                      directory
                                                      65536
                                                      16
                                                      1024
                                                      4096))

(defun %read-config-from-source-ref (source-ref directory)
  (git-agent-workflow.config::%read-config ".gaw/config"
                                           source-ref
                                           directory
                                           65536
                                           16
                                           1024
                                           4096))

(defun %config-failure-reason (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (config-error (condition)
      (config-error-reason condition))))

(defun %assert-config-error (reason thunk)
  (assert (eq reason
              (%config-failure-reason thunk))))

(defun %workspace-summary (config)
  (mapcar (lambda (entry)
            (list (workspace-entry-kind entry)
                  (workspace-entry-path entry)))
          (config-workspace config)))

(defun %test-core-accepts-valid-configs ()
  (let ((config (%parse-config
                 "(:workspace ((:file \"AGENTS.md\") (:directory \"notes\")))")))
    (assert (config-p config))
    (assert (every #'workspace-entry-p
                   (config-workspace config)))
    (assert (equal '((:file "AGENTS.md")
                     (:directory "notes"))
                   (%workspace-summary config))))
  (assert (null (config-workspace
                 (%parse-config "(:workspace ())"))))
  (assert (equal '((:file "a\"b"))
                 (%workspace-summary
                  (%parse-config
                   (format nil
                           " ; comment~%(:workspace (~C(:file \"a\\\"b\"))) ; eof"
                           #\Tab))))))

(defun %test-core-rejects-invalid-encoding-and-syntax ()
  (dolist (octets (list (make-array 3
                                    :element-type '(unsigned-byte 8)
                                    :initial-contents '(239 187 191))
                        (make-array 1
                                    :element-type '(unsigned-byte 8)
                                    :initial-contents '(255))
                        (make-array 2
                                    :element-type '(unsigned-byte 8)
                                    :initial-contents '(195 40))
                        (make-array 2
                                    :element-type '(unsigned-byte 8)
                                    :initial-contents '(192 175))))
    (%assert-config-error :invalid-syntax
                          (lambda ()
                            (%parse-config-octets octets))))
  (dolist (text '(""
                  "(:workspace ()) (:workspace ())"
                  "'(:workspace ())"
                  "`(:workspace ())"
                  ",(:workspace ())"
                  "(:workspace . ())"
                  "#.(error \"no\")"
                  "(:workspace nil)"
                  "(:workspace ((:file \"bad\\npath\")))"
                  "(:workspace ((:file \"unterminated)))"))
    (%assert-config-error :invalid-syntax
                          (lambda ()
                            (%parse-config text))))
  (%assert-config-error
   :invalid-syntax
   (lambda ()
     (%parse-config
      (format nil
              "(:workspace ((:file \"line~%break\")))")))))

(defun %test-core-rejects-unknown-keyword-without-interning ()
  (let ((name "GAW-CONFIG-UNKNOWN-KEYWORD-FOR-TEST"))
    (assert (null (find-symbol name
                               '#:keyword)))
    (%assert-config-error
     :invalid-schema
     (lambda ()
       (%parse-config
        "(:workspace () :gaw-config-unknown-keyword-for-test ())")))
    (assert (null (find-symbol name
                               '#:keyword)))))

(defun %test-core-rejects-invalid-schema ()
  (dolist (text '("()"
                  "(:file ())"
                  "(:workspace)"
                  "(:workspace () :workspace ())"
                  "(:workspace ((:file)))"
                  "(:workspace ((:file \"a\" \"b\")))"
                  "(:workspace ((:directory)))"
                  "(:workspace ((:file \"a\") (:directory \"a\")))"))
    (%assert-config-error :invalid-schema
                          (lambda ()
                            (%parse-config text)))))

(defun %test-core-validates-workspace-paths ()
  (dolist (path '(""
                  "/absolute"
                  "trailing/"
                  "a//b"
                  "."
                  ".."
                  "a/./b"
                  "a/../b"
                  "a\\b"
                  ".gaw"
                  ".GAW/config"
                  ".git"
                  "a/.GiT/b"))
    (%assert-config-error
     :invalid-schema
     (lambda ()
       (%parse-config
        (format nil
                "(:workspace ((:file ~S)))"
                path)))))
  (assert (equal '((:file "parent")
                   (:directory "parent/child"))
                 (%workspace-summary
                  (%parse-config
                   "(:workspace ((:file \"parent\") (:directory \"parent/child\")))")))))

(defun %nested-list-text (depth)
  (concatenate 'string
               (make-string depth
                            :initial-element #\()
               (make-string depth
                            :initial-element #\))))

(defun %workspace-text (count)
  (with-output-to-string (stream)
    (write-string "(:workspace ("
                  stream)
    (dotimes (index count)
      (format stream
              "(:file \"p~D\")"
              index))
    (write-string "))"
                  stream)))

(defun %test-core-enforces-resource-limits ()
  (%assert-config-error :invalid-syntax
                        (lambda ()
                          (%parse-config-octets
                           (make-array 65536
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 32))))
  (%assert-config-error :limit-exceeded
                        (lambda ()
                          (%parse-config-octets
                           (make-array 65537
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 32))))
  (%assert-config-error :invalid-schema
                        (lambda ()
                          (%parse-config (%nested-list-text 16))))
  (%assert-config-error :limit-exceeded
                        (lambda ()
                          (%parse-config (%nested-list-text 17))))
  (assert (= 1024
             (length (config-workspace
                      (%parse-config (%workspace-text 1024))))))
  (%assert-config-error :limit-exceeded
                        (lambda ()
                          (%parse-config (%workspace-text 1025))))
  (let ((maximum-path (make-string 4096
                                   :initial-element #\a))
        (oversized-path (make-string 4097
                                     :initial-element #\a)))
    (assert (= 4096
               (length
                (workspace-entry-path
                 (first
                  (config-workspace
                   (%parse-config
                    (format nil
                            "(:workspace ((:file ~S)))"
                            maximum-path))))))))
    (%assert-config-error
     :limit-exceeded
     (lambda ()
       (%parse-config
        (format nil
                "(:workspace ((:file ~S)))"
                oversized-path))))))

(defun %test-core-uses-explicit-resource-limits ()
  (let ((octets (%octets
                 "(:workspace ((:file \"path\")))")))
    (%assert-config-error
     :limit-exceeded
     (lambda ()
       (git-agent-workflow.config::%config-from-octets
        octets
        (1- (length octets))
        16
        1024
        4096)))
    (%assert-config-error
     :limit-exceeded
     (lambda ()
       (git-agent-workflow.config::%config-from-octets
        octets
        65536
        1
        1024
        4096)))
    (%assert-config-error
     :limit-exceeded
     (lambda ()
       (git-agent-workflow.config::%config-from-octets
        octets
        65536
        16
        0
        4096)))
    (%assert-config-error
     :limit-exceeded
     (lambda ()
       (git-agent-workflow.config::%config-from-octets
        octets
        65536
        16
        1024
        3)))))

(defun %test-public-values-are-defensively-readable ()
  (let* ((config (%parse-config
                  "(:workspace ((:file \"path\")))"))
         (workspace (config-workspace config))
         (entry (first workspace))
         (path (workspace-entry-path entry)))
    (setf (first workspace)
          nil
          (char path 0)
          #\X)
    (assert (workspace-entry-p
             (first (config-workspace config))))
    (assert (string= "path"
                     (workspace-entry-path entry)))
    (assert (not (fboundp '(setf config-workspace))))
    (assert (not (fboundp '(setf workspace-entry-path))))
    (assert (not (fboundp '(setf workspace-entry-kind))))))

(defun %repository-git (directory &rest arguments)
  (call-git (append (list "-C"
                          (namestring directory))
                    arguments)))

(defun %hash-test-octets (directory octets)
  (let ((input-path (merge-pathnames "config-input"
                                     directory)))
    (write-test-octets input-path
                       octets)
    (%repository-git directory
                     "hash-object"
                     "-w"
                     "--"
                     "config-input")))

(defun %install-current-ref-chain (directory commit-oid)
  (%repository-git directory
                   "update-ref"
                   "refs/heads/test"
                   commit-oid)
  (%repository-git directory
                   "symbolic-ref"
                   "refs/gaw/HEAD"
                   "refs/heads/test"))

(defun %create-config-commit (directory octets
                              &key
                                (mode "100644")
                                tree
                                missing)
  (%repository-git directory
                   "read-tree"
                   "--empty")
  (unless missing
    (let ((blob-oid (%hash-test-octets directory
                                       octets)))
      (%repository-git directory
                       "update-index"
                       "--add"
                       "--cacheinfo"
                       (if tree
                           "100644"
                           mode)
                       blob-oid
                       (if tree
                           ".gaw/config/child"
                           ".gaw/config"))))
  (let* ((tree-oid (%repository-git directory
                                    "write-tree"))
         (commit-oid
           (%repository-git directory
                            "-c"
                            "user.name=GAW Test"
                            "-c"
                            "user.email=gaw-test@example.invalid"
                            "commit-tree"
                            tree-oid
                            "-m"
                            "config test")))
    (%install-current-ref-chain directory
                                commit-oid)
    commit-oid))

(defun %test-runtime-reads-current-gaw-commit ()
  (with-test-repository (directory)
    (%create-config-commit
     directory
     (%octets "(:workspace ((:file \"AGENTS.md\")))"))
    (assert (equal '((:file "AGENTS.md"))
                   (%workspace-summary (read-config directory))))
    (let ((subdirectory (merge-pathnames "nested/directory/"
                                         directory)))
      (ensure-directories-exist
       (merge-pathnames "placeholder"
                        subdirectory))
      (assert (equal '((:file "AGENTS.md"))
                     (%workspace-summary
                      (read-config subdirectory)))))))

(defun %test-runtime-fixes-commit-before-reading ()
  (with-test-repository (directory)
    (%create-config-commit
     directory
     (%octets "(:workspace ((:file \"old\")))"))
    (let ((fixed-oid
            (git-agent-workflow.config::%resolve-commit
             (current-ref directory)
             directory)))
      (%create-config-commit
       directory
       (%octets "(:workspace ((:file \"new\")))"))
      (assert (equal '((:file "old"))
                     (%workspace-summary
                      (%read-config-at-commit fixed-oid
                                              directory)))))))

(defun %test-runtime-reads-explicit-tree-object ()
  (with-test-repository (directory)
    (let* ((commit-oid
             (%create-config-commit
              directory
              (%octets "(:workspace ((:file \"tree\")))")))
           (tree-oid
             (%repository-git directory
                              "rev-parse"
                              (concatenate 'string
                                           commit-oid
                                           "^{tree}"))))
      (assert (equal '((:file "tree"))
                     (%workspace-summary
                      (read-config-at-tree directory
                                           tree-oid))))
      (assert
       (signals error
         (read-config-at-tree directory
                              (subseq tree-oid 0 12)))))))

(defun %test-runtime-reads-explicit-blob-object ()
  (with-test-repository (directory)
    (let ((valid
            (%hash-test-octets
             directory
             (%octets "(:workspace ((:file \"blob\")))")))
          (invalid
            (%hash-test-octets
             directory
             (%octets "(:workspace ((:file \"bad\\npath\")))"))))
      (assert (equal '((:file "blob"))
                     (%workspace-summary
                      (read-config-blob directory valid))))
      (%assert-config-error :invalid-syntax
                            (lambda ()
                              (read-config-blob directory invalid))))))

(defun %test-runtime-receives-source-ref-explicitly ()
  (with-test-repository (directory)
    (%create-config-commit
     directory
     (%octets "(:workspace ((:file \"explicit\")))"))
    (%repository-git directory
                     "symbolic-ref"
                     "--delete"
                     "refs/gaw/HEAD")
    (assert (equal '((:file "explicit"))
                   (%workspace-summary
                    (%read-config-from-source-ref
                     "refs/heads/test"
                     directory))))))

(defun %test-runtime-classifies-config-tree-entries ()
  (dolist (case '((:missing nil nil t)
                  (:invalid-object "100755" nil nil)
                  (:invalid-object "120000" nil nil)
                  (:invalid-object "100644" t nil)))
    (destructuring-bind (reason mode tree missing)
        case
      (with-test-repository (directory)
        (%create-config-commit
         directory
         (%octets "(:workspace ())")
         :mode mode
         :tree tree
         :missing missing)
        (%assert-config-error reason
                              (lambda ()
                                (read-config directory)))))))

(defun %test-runtime-enforces-size-before-decoding ()
  (with-test-repository (directory)
    (%create-config-commit
     directory
     (make-array 65537
                 :element-type '(unsigned-byte 8)
                 :initial-element 32))
    (%assert-config-error :limit-exceeded
                          (lambda ()
                            (read-config directory)))))

(defun %test-runtime-decodes-blob-strictly ()
  (with-test-repository (directory)
    (%create-config-commit
     directory
     (make-array 1
                 :element-type '(unsigned-byte 8)
                 :initial-element 255))
    (%assert-config-error :invalid-syntax
                          (lambda ()
                            (read-config directory)))))

(defun %test-runtime-propagates-non-config-failures ()
  (with-test-repository (directory)
    (assert (signals current-ref-error
              (read-config directory)))
    (let ((condition
            (handler-case
                (%read-config-at-commit
                 (make-string 40
                              :initial-element #\0)
                 directory)
              (error (condition)
                condition))))
      (assert condition)
      (assert (not (typep condition
                          'config-error))))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.config)))
    (dolist (name '("READ-CONFIG"
                    "READ-CONFIG-AT-TREE"
                    "READ-CONFIG-BLOB"
                    "CONFIG"
                    "CONFIG-P"
                    "CONFIG-WORKSPACE"
                    "WORKSPACE-ENTRY"
                    "WORKSPACE-ENTRY-P"
                    "WORKSPACE-ENTRY-KIND"
                    "WORKSPACE-ENTRY-PATH"
                    "CONFIG-ERROR"
                    "CONFIG-ERROR-REASON"))
      (multiple-value-bind (symbol status)
          (find-symbol name
                       package)
        (assert symbol)
        (assert (eq :external
                    status))))
    (dolist (name '("%CONFIG-FROM-OCTETS"
                    "%RESOLVE-COMMIT"
                    "%READ-CONFIG-AT-COMMIT"
                    "%READ-CONFIG"))
      (multiple-value-bind (symbol status)
          (find-symbol name
                       package)
        (assert symbol)
        (assert (eq :internal
                    status))))))

(defun %run-config-tests ()
  (%test-core-accepts-valid-configs)
  (%test-core-rejects-invalid-encoding-and-syntax)
  (%test-core-rejects-unknown-keyword-without-interning)
  (%test-core-rejects-invalid-schema)
  (%test-core-validates-workspace-paths)
  (%test-core-enforces-resource-limits)
  (%test-core-uses-explicit-resource-limits)
  (%test-public-values-are-defensively-readable)
  (%test-runtime-reads-current-gaw-commit)
  (%test-runtime-fixes-commit-before-reading)
  (%test-runtime-reads-explicit-tree-object)
  (%test-runtime-reads-explicit-blob-object)
  (%test-runtime-receives-source-ref-explicitly)
  (%test-runtime-classifies-config-tree-entries)
  (%test-runtime-enforces-size-before-decoding)
  (%test-runtime-decodes-blob-strictly)
  (%test-runtime-propagates-non-config-failures)
  (%test-public-package-boundary)
  (format t
          "~&All config tests passed.~%")
  t)
