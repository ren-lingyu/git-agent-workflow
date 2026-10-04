(in-package #:git-agent-workflow.workspace)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git run-git-bytes %make-git-entry
                      %mark-intent-to-add-entries
                      %synthesize-index-directories))
    (unless (fboundp function)
      (error "Required workspace runtime dependency is unavailable: ~S"
             function))))

(defun %successful-stdout (invocation operation)
  (unless (zerop (git-invocation-exit-status invocation))
    (error "Git failed while ~A: ~A"
           operation (git-invocation-stderr invocation)))
  (git-invocation-stdout invocation))

(defun %ascii-octets-to-string (octets start end)
  (let ((result (make-string (- end start))))
    (loop for source from start below end
          for target from 0
          for octet = (aref octets source)
          do (when (> octet 127)
               (error "Git returned non-ASCII metadata"))
             (setf (char result target) (code-char octet)))
    result))

(defun %parse-records (octets parser)
  (unless (typep octets '(vector (unsigned-byte 8)))
    (error 'type-error :datum octets
                       :expected-type '(vector (unsigned-byte 8))))
  (loop with start = 0
        while (< start (length octets))
        for end = (position 0 octets :start start)
        do (unless end (error "Git returned unterminated NUL output"))
        collect (funcall parser octets start end)
        do (setf start (1+ end))))

(defun %record-separators (octets start end)
  (let* ((first (position 32 octets :start start :end end))
         (second (and first
                      (position 32 octets :start (1+ first) :end end)))
         (tab (and second
                   (position 9 octets :start (1+ second) :end end))))
    (unless (and first second tab (< tab end))
      (error "Git returned malformed entry output"))
    (values first second tab)))

(defun %parse-tree-record (octets start end)
  (multiple-value-bind (first second tab)
      (%record-separators octets start end)
    (%make-git-entry
     (%ascii-octets-to-string octets start first)
     (%ascii-octets-to-string octets (1+ first) second)
     (%ascii-octets-to-string octets (1+ second) tab)
     (%copy-octet-range octets (1+ tab) end))))

(defun %index-entry-type (mode gitlink-mode blob-type commit-type)
  (if (string= mode gitlink-mode) commit-type blob-type))

(defun %parse-index-record (octets start end gitlink-mode blob-type commit-type)
  (multiple-value-bind (first second tab)
      (%record-separators octets start end)
    (let* ((mode (%ascii-octets-to-string octets start first))
           (stage-text (%ascii-octets-to-string octets (1+ second) tab))
           (stage (parse-integer stage-text :junk-allowed nil)))
      (unless (<= 0 stage 3)
        (error "Git returned an invalid index stage"))
      (%make-git-entry
       mode
       (%index-entry-type mode gitlink-mode blob-type commit-type)
       (%ascii-octets-to-string octets (1+ first) second)
       (%copy-octet-range octets (1+ tab) end)
       stage))))

(defun %read-path-records (arguments directory operation)
  (%parse-records
   (%successful-stdout
    (run-git-bytes arguments directory)
    operation)
   #'%copy-octet-range))

(defun %head-tree-object-id (directory)
  (let ((invocation
          (run-git '("rev-parse" "--verify" "--end-of-options" "HEAD^{tree}")
                   directory)))
    (when (zerop (git-invocation-exit-status invocation))
      (git-invocation-stdout invocation))))

(defun %intent-to-add-paths (directory)
  (let ((head-tree (%head-tree-object-id directory)))
    (unless head-tree
      (return-from %intent-to-add-paths '()))
    (let* ((base-arguments
             (list "diff-index" "--cached" "--name-only" "-z"
                   "--no-ext-diff" "--no-renames"))
           (visible
             (%read-path-records
              (append base-arguments
                      (list "--ita-visible-in-index" head-tree "--"))
              directory
              "reading visible intent-to-add entries"))
           (invisible
             (%read-path-records
              (append base-arguments
                      (list "--ita-invisible-in-index" head-tree "--"))
              directory
              "reading hidden intent-to-add entries")))
      (set-difference visible invisible :test #'equalp))))

(defun %worktree-root (directory)
  (check-type directory pathname)
  (let ((invocation (run-git '("rev-parse" "--show-toplevel") directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-workspace-error :not-worktree
                               "The directory is not a Git worktree"))
    (uiop:ensure-directory-pathname
     (truename (git-invocation-stdout invocation)))))

(defun %list-worktrees (directory)
  (%parse-worktrees
   (%successful-stdout
    (run-git '("worktree" "list" "--porcelain" "-z") directory)
    "listing worktrees")))

(defun %current-local-head-ref (directory source-ref-prefix)
  (let ((invocation (run-git '("symbolic-ref" "--quiet" "HEAD") directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-workspace-error :detached-head
                               "The worktree HEAD is detached or unborn"))
    (let ((head-ref (git-invocation-stdout invocation)))
      (unless (and (> (length head-ref) (length source-ref-prefix))
                   (string= source-ref-prefix head-ref
                            :end2 (length source-ref-prefix)))
        (%signal-workspace-error :detached-head
                                 "The worktree HEAD is not a local branch"))
      head-ref)))

(defun %git-path (name directory)
  (%successful-stdout
   (run-git (list "rev-parse" "--path-format=absolute" "--git-path" name)
            directory)
   "locating Git operation state"))

(defun %operation-states (directory operation-state-paths)
  (remove-if-not (lambda (path) (probe-file (%git-path path directory)))
                 operation-state-paths))

(defun %read-tree-snapshot (directory tree-oid)
  (%parse-records
   (%successful-stdout
    (run-git-bytes (list "ls-tree" "-r" "-t" "-z" "--full-tree" tree-oid)
                   directory)
    "reading a Git tree")
   #'%parse-tree-record))

(defun %read-index-snapshot (directory gitlink-mode blob-type commit-type
                             tree-mode tree-type)
  (let* ((entries
           (%parse-records
            (%successful-stdout
             (run-git-bytes '("ls-files" "--stage" "-z") directory)
             "reading the Git index")
            (lambda (octets start end)
              (%parse-index-record octets start end
                                   gitlink-mode blob-type commit-type))))
         (marked-entries
           (if (find-if (lambda (entry)
                          (plusp (git-entry-stage entry)))
                        entries)
               entries
               (%mark-intent-to-add-entries
                entries
                (%intent-to-add-paths directory)))))
    (%synthesize-index-directories marked-entries tree-mode tree-type)))
