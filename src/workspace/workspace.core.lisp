(in-package #:git-agent-workflow.workspace)

(define-condition workspace-error (error)
  ((reason :initarg :reason
           :reader workspace-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader workspace-error-detail))
  (:report (lambda (condition stream)
             (if (workspace-error-detail condition)
                 (format stream
                         "GAW workspace failed (~S): ~A"
                         (workspace-error-reason condition)
                         (workspace-error-detail condition))
                 (format stream
                         "GAW workspace failed (~S)"
                         (workspace-error-reason condition))))))

(defstruct (git-entry
            (:constructor %make-git-entry
                (mode type object-id path
                 &optional (stage 0) (intent-to-add-p nil)))
            (:copier nil))
  (mode "" :type string :read-only t)
  (type "" :type string :read-only t)
  (object-id "" :type string :read-only t)
  (path #() :type (vector (unsigned-byte 8)) :read-only t)
  (stage 0 :type (integer 0 3) :read-only t)
  (intent-to-add-p nil :type boolean :read-only t))

(defun %signal-workspace-error (reason control &rest arguments)
  (error 'workspace-error
         :reason reason
         :detail (when control
                   (apply #'format nil control arguments))))

(defun %copy-octet-range (octets start end)
  (let ((result (make-array (- end start)
                            :element-type '(unsigned-byte 8))))
    (replace result octets :start2 start :end2 end)
    result))

(defun %octet-path= (left right)
  (equalp left right))

(defun %octet-path-prefix-p (prefix path)
  (and (< (length prefix) (length path))
       (= (aref path (length prefix)) 47)
       (loop for index below (length prefix)
             always (= (aref prefix index)
                       (aref path index)))))

(defun %ascii-downcase-octet (octet)
  (if (<= 65 octet 90)
      (+ octet 32)
      octet))

(defun %ascii-octet-path-component= (path component)
  (let ((end (or (position 47 path) (length path))))
    (and (= end (length component))
         (loop for index below end
               always (= (%ascii-downcase-octet (aref path index))
                         (%ascii-downcase-octet
                          (aref component index)))))))

(defun %reserved-protocol-path-p (path protocol-root)
  (%ascii-octet-path-component= path protocol-root))

(defun entry-at-path (path entries)
  (find path entries :test #'%octet-path= :key #'git-entry-path))

(defun %tree-entry-p (entry tree-mode tree-type)
  (and (string= (git-entry-mode entry) tree-mode)
       (string= (git-entry-type entry) tree-type)))

(defun %file-entry-p (entry file-modes blob-type)
  (and (member (git-entry-mode entry) file-modes :test #'string=)
       (string= (git-entry-type entry) blob-type)))

(defun %workspace-octet-entries (workspace)
  (mapcar (lambda (entry)
            (cons (car entry)
                  (string-to-octets (cdr entry) :encoding :utf-8)))
          workspace))

(defun %declaration-covers-entry-p (declaration entry tree-mode tree-type)
  (let ((kind (car declaration))
        (workspace-path (cdr declaration))
        (entry-path (git-entry-path entry)))
    (if (%tree-entry-p entry tree-mode tree-type)
        (or (and (eq kind :directory)
                 (or (%octet-path= workspace-path entry-path)
                     (%octet-path-prefix-p workspace-path entry-path)))
            (%octet-path-prefix-p entry-path workspace-path))
        (or (and (eq kind :file)
                 (%octet-path= workspace-path entry-path))
            (and (eq kind :directory)
                 (%octet-path-prefix-p workspace-path entry-path))))))

(defun %validate-declaration-kind (declaration entries file-modes tree-mode
                                   blob-type tree-type)
  (let* ((kind (car declaration))
         (path (cdr declaration))
         (entry (entry-at-path path entries)))
    (when entry
      (unless (case kind
                (:file (%file-entry-p entry file-modes blob-type))
                (:directory (%tree-entry-p entry tree-mode tree-type)))
        (%signal-workspace-error
         :invalid-workspace
         "A declared workspace path has the wrong Git kind")))))

(defun %zero-object-id-p (object-id)
  (and (plusp (length object-id))
       (every (lambda (character) (char= character #\0)) object-id)))

(defun %mark-intent-to-add-entries (entries paths)
  (mapcar
   (lambda (entry)
     (%make-git-entry (git-entry-mode entry)
                      (git-entry-type entry)
                      (git-entry-object-id entry)
                      (git-entry-path entry)
                      (git-entry-stage entry)
                      (not (null (member (git-entry-path entry)
                                         paths
                                         :test #'equalp)))))
   entries))

(defun %validate-snapshot-shape (entries file-modes tree-mode gitlink-mode
                                 blob-type tree-type)
  (dolist (entry entries)
      (when (plusp (git-entry-stage entry))
        (%signal-workspace-error :unmerged-index
                                 "The index contains unmerged entries"))
      (when (or (git-entry-intent-to-add-p entry)
                (%zero-object-id-p (git-entry-object-id entry)))
        (%signal-workspace-error :invalid-workspace
                                 "The index contains an intent-to-add entry"))
      (when (string= (git-entry-mode entry) gitlink-mode)
        (%signal-workspace-error :invalid-workspace
                                 "Gitlinks are not supported in a GAW tree"))
      (unless (or (%tree-entry-p entry tree-mode tree-type)
                  (%file-entry-p entry file-modes blob-type))
        (%signal-workspace-error :invalid-workspace
                                 "The GAW tree contains an unsupported object")))
  entries)

(defun %validate-workspace (workspace entries protocol-root file-modes
                            tree-mode gitlink-mode blob-type tree-type)
  (%validate-snapshot-shape entries file-modes tree-mode gitlink-mode
                            blob-type tree-type)
  (let ((declarations (%workspace-octet-entries workspace)))
    (dolist (declaration declarations)
      (%validate-declaration-kind declaration entries file-modes tree-mode
                                  blob-type tree-type))
    (dolist (entry entries)
      (let ((path (git-entry-path entry)))
        (cond
          ((or (%octet-path= path protocol-root)
               (%octet-path-prefix-p protocol-root path)))
          ((%reserved-protocol-path-p path protocol-root)
           (%signal-workspace-error
            :invalid-workspace
            "The reserved protocol path has non-canonical spelling"))
          ((not (some (lambda (declaration)
                        (%declaration-covers-entry-p declaration entry
                                                     tree-mode tree-type))
                      declarations))
           (%signal-workspace-error
            :invalid-workspace
            "The GAW tree contains a path outside the declared workspace")))))
    workspace))

(defun %project-entry-conflicts-p (entry declaration tree-mode tree-type)
  (let ((project-path (git-entry-path entry))
        (workspace-path (cdr declaration)))
    (if (%tree-entry-p entry tree-mode tree-type)
        (or (%octet-path= project-path workspace-path)
            (%octet-path-prefix-p workspace-path project-path))
        (or (%octet-path= project-path workspace-path)
            (%octet-path-prefix-p project-path workspace-path)
            (%octet-path-prefix-p workspace-path project-path)))))

(defun %find-project-path-conflict (workspace entries protocol-root
                                    tree-mode tree-type)
  (let ((declarations (%workspace-octet-entries workspace)))
    (dolist (entry entries)
      (let ((path (git-entry-path entry)))
        (when (%reserved-protocol-path-p path protocol-root)
          (return-from %find-project-path-conflict path))
        (when (some (lambda (declaration)
                      (%project-entry-conflicts-p entry declaration
                                                  tree-mode tree-type))
                    declarations)
          (return-from %find-project-path-conflict path))))
    nil))

(defun %parent-paths (path)
  (loop for slash = (position 47 path)
          then (position 47 path :start (1+ slash))
        while slash
        collect (%copy-octet-range path 0 slash)))

(defun %synthesize-index-directories (entries tree-mode tree-type)
  (let ((result (copy-list entries)))
    (dolist (entry entries)
      (dolist (path (%parent-paths (git-entry-path entry)))
        (unless (entry-at-path path result)
          (push (%make-git-entry tree-mode tree-type "" path 0)
                result))))
    (nreverse result)))
