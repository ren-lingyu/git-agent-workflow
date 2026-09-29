(in-package #:git-agent-workflow.config)

(define-condition config-error (error)
  ((reason :initarg :reason
           :reader config-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader %config-error-detail))
  (:report (lambda (condition stream)
             (if (%config-error-detail condition)
                 (format stream
                         "Invalid GAW config (~S): ~A"
                         (config-error-reason condition)
                         (%config-error-detail condition))
                 (format stream
                         "Invalid GAW config (~S)"
                         (config-error-reason condition))))))

(defstruct (workspace-entry
            (:constructor %make-workspace-entry (kind path))
            (:conc-name %workspace-entry-)
            (:copier nil))
  (kind nil :read-only t)
  (path "" :read-only t))

(defstruct (config
            (:constructor %make-config (workspace))
            (:conc-name %config-)
            (:copier nil))
  (workspace '() :read-only t))

(defun workspace-entry-kind (entry)
  (check-type entry
              workspace-entry)
  (%workspace-entry-kind entry))

(defun workspace-entry-path (entry)
  (check-type entry
              workspace-entry)
  (copy-seq (%workspace-entry-path entry)))

(defun config-workspace (config)
  (check-type config
              config)
  (copy-list (%config-workspace config)))

(defun %signal-config-error (reason control &rest arguments)
  (error 'config-error
         :reason reason
         :detail (when control
                   (apply #'format
                          nil
                          control
                          arguments))))

(defun %decode-config-octets (octets maximum-config-size)
  (unless (typep octets
                 '(vector (unsigned-byte 8)))
    (error 'type-error
           :datum octets
           :expected-type '(vector (unsigned-byte 8))))
  (when (> (length octets)
           maximum-config-size)
    (%signal-config-error :limit-exceeded
                          "Config exceeds ~D octets"
                          maximum-config-size))
  (let ((text
          (handler-case
              (octets-to-string octets
                                :encoding :utf-8
                                :errorp t)
            (character-decoding-error ()
              (%signal-config-error :invalid-syntax
                                    "Config is not valid UTF-8")))))
    (when (and (plusp (length text))
               (= (char-code (char text 0))
                  #xfeff))
      (%signal-config-error :invalid-syntax
                            "UTF-8 BOM is not allowed"))
    text))

(defun %config-whitespace-p (character)
  (member character
          '(#\Space #\Tab #\Newline #\Return)
          :test #'char=))

(defun %ascii-control-character-p (character)
  (let ((code (char-code character)))
    (or (< code 32)
        (= code 127))))

(defun %known-config-keyword-p (token)
  (member token
          '(":workspace" ":file" ":directory")
          :test #'string=))

(defun %validate-config-lexemes (text maximum-list-depth)
  (let ((index 0)
        (length (length text))
        (depth 0))
    (labels ((syntax-error (control &rest arguments)
               (apply #'%signal-config-error
                      :invalid-syntax
                      control
                      arguments))
             (scan-comment ()
               (incf index)
               (loop while (< index length)
                     for character = (char text index)
                     do (incf index)
                     when (char= character #\Newline)
                       do (return)))
             (scan-string ()
               (incf index)
               (loop while (< index length)
                     for character = (char text index)
                     do (cond
                          ((char= character #\")
                           (incf index)
                           (return-from scan-string))
                          ((char= character #\\)
                           (incf index)
                           (when (>= index length)
                             (syntax-error "Incomplete string escape"))
                           (unless (member (char text index)
                                           '(#\" #\\)
                                           :test #'char=)
                             (syntax-error "Unsupported string escape"))
                           (incf index))
                          ((%ascii-control-character-p character)
                           (syntax-error
                            "Literal ASCII control character in string"))
                          (t
                           (incf index))))
               (syntax-error "Unterminated string"))
             (token-delimiter-p (character)
               (or (%config-whitespace-p character)
                   (member character
                           '(#\( #\) #\;)
                           :test #'char=)))
             (scan-token ()
               (let ((start index))
                 (loop while (and (< index length)
                                  (not (token-delimiter-p
                                        (char text index))))
                       do (incf index))
                 (let ((token (subseq text
                                      start
                                      index)))
                   (cond
                     ((%known-config-keyword-p token))
                     ((and (plusp (length token))
                           (char= (char token 0)
                                  #\:))
                      (%signal-config-error :invalid-schema
                                            "Unknown config keyword"))
                     (t
                      (syntax-error "Unsupported token")))))))
      (loop while (< index length)
            for character = (char text index)
            do (cond
                 ((%config-whitespace-p character)
                  (incf index))
                 ((char= character #\;)
                  (scan-comment))
                 ((char= character #\")
                  (scan-string))
                 ((char= character #\()
                  (incf depth)
                  (when (> depth
                           maximum-list-depth)
                    (%signal-config-error :limit-exceeded
                                          "List nesting exceeds ~D"
                                          maximum-list-depth))
                  (incf index))
                 ((char= character #\))
                  (decf depth)
                  (when (minusp depth)
                    (syntax-error "Unmatched closing parenthesis"))
                  (incf index))
                 (t
                  (scan-token))))
      (unless (zerop depth)
        (syntax-error "Unclosed list"))
      text)))

(defun %read-config-form (text)
  (let ((*read-eval* nil)
        (*readtable* (copy-readtable nil))
        (*package* (find-package '#:git-agent-workflow.config))
        (eof (gensym "EOF")))
    (handler-case
        (with-input-from-string (stream text)
          (let ((form (read stream
                            nil
                            eof)))
            (when (eq form eof)
              (%signal-config-error :invalid-syntax
                                    "Config is empty"))
            (unless (eq (read stream
                              nil
                              eof)
                        eof)
              (%signal-config-error :invalid-syntax
                                    "Config contains multiple forms"))
            form))
      (end-of-file ()
        (%signal-config-error :invalid-syntax
                              "Unexpected end of config"))
      (reader-error ()
        (%signal-config-error :invalid-syntax
                              "Config reader rejected input")))))

(defun %proper-list-p (object)
  (loop with slow = object
        with fast = object
        do (cond
             ((null fast)
              (return t))
             ((atom fast)
              (return nil))
             ((null (cdr fast))
              (return t))
             ((atom (cdr fast))
              (return nil))
             (t
              (setf slow (cdr slow)
                    fast (cddr fast))
              (when (eq slow fast)
                (return nil))))))

(defun %ascii-downcase-code (character)
  (let ((code (char-code character)))
    (if (<= (char-code #\A)
            code
            (char-code #\Z))
        (+ code
           (- (char-code #\a)
              (char-code #\A)))
        code)))

(defun %ascii-case-insensitive= (left right)
  (and (= (length left)
          (length right))
       (loop for left-character across left
             for right-character across right
             always (= (%ascii-downcase-code left-character)
                       (%ascii-downcase-code right-character)))))

(defun %split-workspace-path (path)
  (loop with start = 0
        for separator = (position #\/
                                  path
                                  :start start)
        collect (subseq path
                        start
                        separator)
        while separator
        do (setf start (1+ separator))))

(defun %validate-workspace-path (path maximum-workspace-path-size)
  (unless (stringp path)
    (%signal-config-error :invalid-schema
                          "Workspace path is not a string"))
  (when (zerop (length path))
    (%signal-config-error :invalid-schema
                          "Workspace path is empty"))
  (when (> (string-size-in-octets path
                                  :encoding :utf-8
                                  :errorp t)
           maximum-workspace-path-size)
    (%signal-config-error :limit-exceeded
                          "Workspace path exceeds ~D UTF-8 octets"
                          maximum-workspace-path-size))
  (when (or (char= (char path 0)
                   #\/)
            (char= (char path
                         (1- (length path)))
                   #\/))
    (%signal-config-error :invalid-schema
                          "Workspace path is not relative and canonical"))
  (when (position #\\
                  path)
    (%signal-config-error :invalid-schema
                          "Workspace path contains a backslash"))
  (let ((components (%split-workspace-path path)))
    (when (some (lambda (component)
                  (or (zerop (length component))
                      (string= component ".")
                      (string= component "..")))
                components)
      (%signal-config-error :invalid-schema
                            "Workspace path contains an invalid component"))
    (when (or (%ascii-case-insensitive= (first components)
                                        ".gaw")
              (some (lambda (component)
                      (%ascii-case-insensitive= component
                                               ".git"))
                    components))
      (%signal-config-error :invalid-schema
                            "Workspace path uses a reserved component")))
  path)

(defun %workspace-entry-from-form (form maximum-workspace-path-size)
  (unless (and (%proper-list-p form)
               (= (length form)
                  2))
    (%signal-config-error :invalid-schema
                          "Workspace entry must contain kind and path"))
  (destructuring-bind (kind path)
      form
    (unless (member kind
                    '(:file :directory)
                    :test #'eq)
      (%signal-config-error :invalid-schema
                            "Workspace entry has an invalid kind"))
    (%validate-workspace-path path
                              maximum-workspace-path-size)
    (%make-workspace-entry kind
                           (copy-seq path))))

(defun %workspace-from-form (form
                             maximum-workspace-entries
                             maximum-workspace-path-size)
  (unless (%proper-list-p form)
    (%signal-config-error :invalid-schema
                          "Workspace must be a proper list"))
  (when (> (length form)
           maximum-workspace-entries)
    (%signal-config-error :limit-exceeded
                          "Workspace contains more than ~D entries"
                          maximum-workspace-entries))
  (let ((seen (make-hash-table :test #'equal)))
    (mapcar (lambda (entry-form)
              (let* ((entry (%workspace-entry-from-form
                             entry-form
                             maximum-workspace-path-size))
                     (path (%workspace-entry-path entry)))
                (multiple-value-bind (value present-p)
                    (gethash path
                             seen)
                  (declare (ignore value))
                  (when present-p
                    (%signal-config-error :invalid-schema
                                          "Duplicate workspace path")))
                (setf (gethash path seen)
                      t)
                entry))
            form)))

(defun %config-from-form (form
                          maximum-workspace-entries
                          maximum-workspace-path-size)
  (unless (%proper-list-p form)
    (%signal-config-error :invalid-schema
                          "Top-level config must be a proper list"))
  (unless (evenp (length form))
    (%signal-config-error :invalid-schema
                          "Top-level config must contain key/value pairs"))
  (let ((workspace nil)
        (workspace-present-p nil))
    (loop for (key value) on form by #'cddr
          do (case key
               (:workspace
                (when workspace-present-p
                  (%signal-config-error :invalid-schema
                                        "Duplicate :workspace field"))
                (setf workspace value
                      workspace-present-p t))
               (otherwise
                (%signal-config-error :invalid-schema
                                      "Unknown top-level field"))))
    (unless workspace-present-p
      (%signal-config-error :invalid-schema
                            "Missing :workspace field"))
    (%make-config (%workspace-from-form
                   workspace
                   maximum-workspace-entries
                   maximum-workspace-path-size))))

(defun %config-from-octets (octets
                            maximum-config-size
                            maximum-list-depth
                            maximum-workspace-entries
                            maximum-workspace-path-size)
  (let* ((text (%decode-config-octets octets
                                      maximum-config-size))
         (validated-text (%validate-config-lexemes
                          text
                          maximum-list-depth))
         (form (%read-config-form validated-text)))
    (%config-from-form form
                       maximum-workspace-entries
                       maximum-workspace-path-size)))
