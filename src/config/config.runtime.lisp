(in-package #:git-agent-workflow.config)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      run-git-bytes
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status
                      %config-from-octets
                      %signal-config-error))
    (unless (fboundp function)
      (error "Required config runtime dependency is unavailable: ~S"
             function))))

(defun %successful-git-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation
           (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %resolve-commit (source-ref directory)
  (let* ((revision (concatenate 'string
                                source-ref
                                "^{commit}"))
         (invocation
           (run-git (list "rev-parse"
                          "--verify"
                          "--end-of-options"
                          revision)
                    directory))
         (object-id
           (%successful-git-stdout invocation
                                   "resolving the current GAW commit")))
    (when (or (zerop (length object-id))
              (find-if (lambda (character)
                         (member character
                                 '(#\Space #\Tab #\Newline #\Return)
                                 :test #'char=))
                       object-id))
      (error "Git returned an invalid commit object ID"))
    object-id))

(defun %hex-digit-p (character)
  (or (digit-char-p character 16)
      nil))

(defun %object-id-length (directory)
  (let* ((invocation
           (run-git '("rev-parse" "--show-object-format")
                    directory))
         (format
           (%successful-git-stdout invocation
                                   "reading the Git object format")))
    (cond
      ((string= format "sha1")
       40)
      ((string= format "sha256")
       64)
      (t
       (error "Unsupported Git object format: ~S"
              format)))))

(defun %ensure-exact-tree-object-id (tree-oid directory)
  (check-type tree-oid
              string)
  (unless (and (= (length tree-oid)
                  (%object-id-length directory))
               (every #'%hex-digit-p
                      tree-oid))
    (error "Not a full Git tree object ID: ~S"
           tree-oid))
  (let* ((invocation
           (run-git (list "cat-file"
                          "-t"
                          tree-oid)
                    directory))
         (type
           (%successful-git-stdout invocation
                                   "verifying the GAW config tree")))
    (unless (string= type "tree")
      (error "Git object is not a tree: ~S"
             tree-oid)))
  tree-oid)

(defun %commit-tree-object-id (commit-oid directory)
  (let* ((revision (concatenate 'string
                                commit-oid
                                "^{tree}"))
         (invocation
           (run-git (list "rev-parse"
                          "--verify"
                          "--end-of-options"
                          revision)
                    directory)))
    (%successful-git-stdout invocation
                            "resolving the current GAW tree")))

(defun %parse-tree-entry (output)
  (when (zerop (length output))
    (return-from %parse-tree-entry
      nil))
  (when (find-if (lambda (character)
                   (member character
                           '(#\Newline #\Return #\Tab)
                           :test #'char=))
                 output)
    (error "Git returned malformed tree entry output"))
  (let* ((first-space (position #\Space
                                output))
         (second-space (and first-space
                            (position #\Space
                                      output
                                      :start (1+ first-space)))))
    (unless (and first-space
                 second-space
                 (not (position #\Space
                                output
                                :start (1+ second-space))))
      (error "Git returned malformed tree entry output"))
    (values (subseq output
                    0
                    first-space)
            (subseq output
                    (1+ first-space)
                    second-space)
            (subseq output
                    (1+ second-space)))))

(defun %config-blob-object-id (commit-oid config-path directory)
  (let* ((invocation
           (run-git (list "--literal-pathspecs"
                          "ls-tree"
                          "--full-tree"
                          "--format=%(objectmode) %(objecttype) %(objectname)"
                          commit-oid
                          "--"
                          config-path)
                    directory))
         (output
           (%successful-git-stdout invocation
                                   "locating the GAW config blob")))
    (multiple-value-bind (mode type object-id)
        (%parse-tree-entry output)
      (unless mode
        (%signal-config-error :missing
                              "~A is absent from the current GAW commit"
                              config-path))
      (unless (and (string= mode
                            "100644")
                   (string= type
                            "blob")
                   (plusp (length object-id)))
        (%signal-config-error :invalid-object
                              "~A is not a 100644 blob"
                              config-path))
      object-id)))

(defun %parse-object-size (output)
  (handler-case
      (let ((size (parse-integer output
                                 :junk-allowed nil)))
        (when (minusp size)
          (error "Git returned a negative object size"))
        size)
    (parse-error ()
      (error "Git returned a malformed object size"))))

(defun %read-config-blob (blob-oid directory maximum-config-size)
  (let* ((size-invocation
           (run-git (list "cat-file"
                          "-s"
                          blob-oid)
                    directory))
         (size-output
           (%successful-git-stdout size-invocation
                                   "reading the GAW config size"))
         (size (%parse-object-size size-output)))
    (when (> size
             maximum-config-size)
      (%signal-config-error :limit-exceeded
                            "Config exceeds ~D octets"
                            maximum-config-size))
    (let* ((blob-invocation
             (run-git-bytes (list "cat-file"
                                  "blob"
                                  blob-oid)
                            directory))
           (octets
             (%successful-git-stdout blob-invocation
                                     "reading the GAW config blob")))
      (unless (= (length octets)
                 size)
        (error "Git config blob size changed while reading"))
      octets)))

(defun %read-config-at-tree (tree-oid
                             config-path
                             directory
                             maximum-config-size
                             maximum-list-depth
                             maximum-workspace-entries
                             maximum-workspace-path-size)
  (%ensure-exact-tree-object-id tree-oid
                                directory)
  (let* ((blob-oid (%config-blob-object-id tree-oid
                                           config-path
                                           directory))
         (octets (%read-config-blob blob-oid
                                    directory
                                    maximum-config-size)))
    (%config-from-octets octets
                         maximum-config-size
                         maximum-list-depth
                         maximum-workspace-entries
                         maximum-workspace-path-size)))

(defun %read-config-at-commit (commit-oid
                               config-path
                               directory
                               maximum-config-size
                               maximum-list-depth
                               maximum-workspace-entries
                               maximum-workspace-path-size)
  (%read-config-at-tree (%commit-tree-object-id commit-oid
                                                directory)
                        config-path
                        directory
                        maximum-config-size
                        maximum-list-depth
                        maximum-workspace-entries
                        maximum-workspace-path-size))

(defun %read-config (config-path
                     source-ref
                     directory
                     maximum-config-size
                     maximum-list-depth
                     maximum-workspace-entries
                     maximum-workspace-path-size)
  (%read-config-at-commit (%resolve-commit source-ref
                                          directory)
                          config-path
                          directory
                          maximum-config-size
                          maximum-list-depth
                          maximum-workspace-entries
                          maximum-workspace-path-size))
