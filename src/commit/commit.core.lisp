(in-package #:git-agent-workflow.commit)

(define-condition commit-error (error)
  ((reason :initarg :reason
           :reader commit-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader %commit-error-detail))
  (:report (lambda (condition stream)
             (if (%commit-error-detail condition)
                 (format stream
                         "GAW commit failed (~S): ~A"
                         (commit-error-reason condition)
                         (%commit-error-detail condition))
                 (format stream
                         "GAW commit failed (~S)"
                         (commit-error-reason condition))))))

(defstruct (tree-entry
            (:constructor %make-tree-entry (mode type path))
            (:copier nil))
  (mode "" :type string :read-only t)
  (type "" :type string :read-only t)
  (path #() :type (vector (unsigned-byte 8)) :read-only t))

(defun %signal-commit-error (reason control &rest arguments)
  (error 'commit-error
         :reason reason
         :detail (when control
                   (apply #'format
                          nil
                          control
                          arguments))))

(defun %ascii-octets-to-string (octets start end)
  (let ((result (make-string (- end start))))
    (loop for source from start below end
          for target from 0
          for octet = (aref octets source)
          do (when (> octet 127)
               (error "Git returned non-ASCII tree metadata"))
             (setf (char result target)
                   (code-char octet)))
    result))

(defun %copy-octet-range (octets start end)
  (let ((result
          (make-array (- end start)
                      :element-type '(unsigned-byte 8))))
    (replace result
             octets
             :start2 start
             :end2 end)
    result))

(defun %parse-tree-record (octets start end)
  (let* ((first-space (position 32 octets :start start :end end))
         (second-space (and first-space
                            (position 32
                                      octets
                                      :start (1+ first-space)
                                      :end end)))
         (tab (and second-space
                   (position 9
                             octets
                             :start (1+ second-space)
                             :end end))))
    (unless (and first-space
                 second-space
                 tab
                 (< tab end))
      (error "Git returned malformed ls-tree output"))
    (%make-tree-entry
     (%ascii-octets-to-string octets start first-space)
     (%ascii-octets-to-string octets (1+ first-space) second-space)
     (%copy-octet-range octets (1+ tab) end))))

(defun %parse-tree-entries (octets)
  (unless (typep octets
                 '(vector (unsigned-byte 8)))
    (error 'type-error
           :datum octets
           :expected-type '(vector (unsigned-byte 8))))
  (loop with start = 0
        while (< start (length octets))
        for end = (position 0 octets :start start)
        do (unless end
             (error "Git returned unterminated ls-tree output"))
        collect (%parse-tree-record octets start end)
        do (setf start (1+ end))))

(defun %octet-path= (left right)
  (equalp left right))

(defun %octet-path-prefix-p (prefix path)
  (and (< (length prefix)
          (length path))
       (= (aref path (length prefix))
          47)
       (loop for index below (length prefix)
             always (= (aref prefix index)
                       (aref path index)))))

(defun %ascii-downcase-octet (octet)
  (if (<= 65 octet 90)
      (+ octet 32)
      octet))

(defun %ascii-octet-path-component= (path component)
  (let ((end (or (position 47 path)
                 (length path))))
    (and (= end (length component))
         (loop for index below end
               always (= (%ascii-downcase-octet (aref path index))
                         (%ascii-downcase-octet
                          (aref component index)))))))

(defun %reserved-protocol-path-p (path protocol-root)
  (%ascii-octet-path-component= path
                                protocol-root))

(defun %entry-at-path (path entries)
  (find path
        entries
        :test #'%octet-path=
        :key #'tree-entry-path))

(defun %tree-entry-tree-p (entry tree-mode tree-type)
  (and (string= (tree-entry-mode entry)
                tree-mode)
       (string= (tree-entry-type entry)
                tree-type)))

(defun %tree-entry-file-p (entry file-modes blob-type)
  (and (member (tree-entry-mode entry)
               file-modes
               :test #'string=)
       (string= (tree-entry-type entry)
                blob-type)))

(defun %workspace-octet-entries (workspace)
  (mapcar (lambda (entry)
            (cons (car entry)
                  (string-to-octets
                   (cdr entry)
                   :encoding :utf-8)))
          workspace))

(defun %declaration-covers-entry-p (declaration entry tree-mode tree-type)
  (let ((kind (car declaration))
        (workspace-path (cdr declaration))
        (entry-path (tree-entry-path entry)))
    (if (%tree-entry-tree-p entry tree-mode tree-type)
        (or (and (eq kind :directory)
                 (or (%octet-path= workspace-path entry-path)
                     (%octet-path-prefix-p workspace-path entry-path)))
            (%octet-path-prefix-p entry-path workspace-path))
        (or (and (eq kind :file)
                 (%octet-path= workspace-path entry-path))
            (and (eq kind :directory)
                 (%octet-path-prefix-p workspace-path entry-path))))))

(defun %validate-declaration-kind (declaration
                                   entries
                                   file-modes
                                   tree-mode
                                   blob-type
                                   tree-type)
  (let* ((kind (car declaration))
         (path (cdr declaration))
         (entry (%entry-at-path path entries)))
    (when entry
      (unless (case kind
                (:file
                 (%tree-entry-file-p entry
                                     file-modes
                                     blob-type))
                (:directory
                 (%tree-entry-tree-p entry
                                     tree-mode
                                     tree-type)))
        (%signal-commit-error :invalid-workspace
                              "A declared workspace path has the wrong Git kind")))))

(defun %validate-workspace-tree (workspace
                                 entries
                                 protocol-root
                                 file-modes
                                 tree-mode
                                 gitlink-mode
                                 blob-type
                                 tree-type)
  (let ((declarations (%workspace-octet-entries workspace)))
    (dolist (entry entries)
      (when (string= (tree-entry-mode entry)
                     gitlink-mode)
        (%signal-commit-error :invalid-workspace
                              "Gitlinks are not supported in a GAW tree"))
      (unless (or (%tree-entry-tree-p entry
                                     tree-mode
                                     tree-type)
                  (%tree-entry-file-p entry
                                      file-modes
                                      blob-type))
        (%signal-commit-error :invalid-workspace
                              "The GAW tree contains an unsupported object")))
    (dolist (declaration declarations)
      (%validate-declaration-kind declaration
                                  entries
                                  file-modes
                                  tree-mode
                                  blob-type
                                  tree-type))
    (dolist (entry entries)
      (let ((path (tree-entry-path entry)))
        (cond
          ((or (%octet-path= path protocol-root)
               (%octet-path-prefix-p protocol-root path)))
          ((%reserved-protocol-path-p path protocol-root)
           (%signal-commit-error :invalid-workspace
                                 "The reserved protocol path has non-canonical spelling"))
          ((not (some (lambda (declaration)
                        (%declaration-covers-entry-p declaration
                                                     entry
                                                     tree-mode
                                                     tree-type))
                      declarations))
           (%signal-commit-error :invalid-workspace
                                 "The GAW tree contains a path outside the declared workspace")))))
    workspace))

(defun %project-entry-conflicts-p (entry declaration tree-mode tree-type)
  (let ((project-path (tree-entry-path entry))
        (workspace-path (cdr declaration)))
    (if (%tree-entry-tree-p entry tree-mode tree-type)
        (or (%octet-path= project-path workspace-path)
            (%octet-path-prefix-p workspace-path project-path))
        (or (%octet-path= project-path workspace-path)
            (%octet-path-prefix-p project-path workspace-path)
            (%octet-path-prefix-p workspace-path project-path)))))

(defun %find-project-path-conflict (workspace
                                    entries
                                    protocol-root
                                    tree-mode
                                    tree-type)
  (let ((declarations (%workspace-octet-entries workspace)))
    (dolist (entry entries)
      (let ((path (tree-entry-path entry)))
        (when (%reserved-protocol-path-p path protocol-root)
          (return-from %find-project-path-conflict path))
        (when (some (lambda (declaration)
                      (%project-entry-conflicts-p entry
                                                  declaration
                                                  tree-mode
                                                  tree-type))
                    declarations)
          (return-from %find-project-path-conflict path))))
    nil))
