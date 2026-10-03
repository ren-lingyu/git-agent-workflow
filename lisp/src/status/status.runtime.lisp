(in-package #:git-agent-workflow.status)

(defun %status-repository (directory)
  (let ((invocation
          (run-git '("rev-parse" "--path-format=absolute"
                     "--git-common-dir") directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-status-error :not-repository "~A"
                            (git-invocation-stderr invocation)))
    (uiop:ensure-directory-pathname
     (pathname (git-invocation-stdout invocation)))))

(defun %status-ref-names (source-refs enumerated-refs selector
                          source-prefix registration-prefix protocol-prefix)
  (let ((selector-target (status-protocol-ref-value selector)))
    (sort
     (remove-duplicates
      (append enumerated-refs
              (loop for source-ref in source-refs
                    collect (concatenate
                             'string registration-prefix
                             (subseq source-ref (length source-prefix))))
              (when (and (eq :symbolic (status-protocol-ref-kind selector))
                         selector-target
                         (uiop:string-prefix-p protocol-prefix
                                               selector-target))
                (list selector-target)))
      :test #'string=)
     #'string<)))

(defun %status-protocol-kind (state)
  (cond
    ((not (ref-state-exists-p state)) :missing)
    ((ref-state-symbolic-p state) :symbolic)
    (t :direct)))

(defun %status-ref-value (state)
  (if (ref-state-symbolic-p state)
      (ref-state-symbolic-target state)
      (ref-state-object-id state)))

(defun %status-inspect-protocol-ref (name directory)
  (handler-case
      (let* ((state (inspect-ref name directory))
             (kind (%status-protocol-kind state))
             (value (%status-ref-value state)))
        (%make-status-protocol-ref name kind value
                                   (if (eq kind :missing) :missing :unclassified)
                                   ""))
    (error (condition)
      (%make-status-protocol-ref name :unreadable nil :unreadable
                                 (princ-to-string condition)))))

(defun %status-registration-ref-p (name registration-prefix)
  (and (> (length name) (length registration-prefix))
       (string= registration-prefix name
                :end2 (length registration-prefix))))

(defun %status-source-for-registration (name registration-prefix source-prefix)
  (concatenate 'string source-prefix
               (subseq name (length registration-prefix))))

(defun %status-classify-registration (ref source-refs
                                      registration-prefix source-prefix)
  (let* ((name (status-protocol-ref-name ref))
         (source (%status-source-for-registration
                  name registration-prefix source-prefix))
         (kind (status-protocol-ref-kind ref))
         (value (status-protocol-ref-value ref)))
    (cond
      ((eq kind :unreadable)
       ref)
      ((eq kind :missing)
       (%make-status-protocol-ref name kind nil :missing
                                  "Registration disappeared during inspection"))
      ((eq kind :direct)
       (%make-status-protocol-ref name kind value :invalid
                                  "Registration must be symbolic"))
      ((or (null value) (not (string= value source)))
       (%make-status-protocol-ref name kind value :invalid
                                  (format nil "Expected target ~A" source)))
      ((not (member source source-refs :test #'string=))
       (%make-status-protocol-ref name kind value :orphan
                                  "Registered source branch is missing"))
      (t
       (%make-status-protocol-ref name kind value :exact "")))))

(defun %status-classify-protocol-ref (ref source-refs
                                      registration-prefix source-prefix
                                      selector-ref)
  (let ((name (status-protocol-ref-name ref)))
    (cond
      ((eq :unreadable (status-protocol-ref-status ref)) ref)
      ((string= name selector-ref) ref)
      ((%status-registration-ref-p name registration-prefix)
       (%status-classify-registration ref source-refs
                                      registration-prefix source-prefix))
      (t
       (%make-status-protocol-ref
        name (status-protocol-ref-kind ref)
        (status-protocol-ref-value ref)
        :unknown "Unknown GAW protocol ref")))))

(defun %status-branch-report (source-ref directory registration)
  (let* ((ref-state (inspect-ref source-ref directory))
         (invalid-ref (or (not (ref-state-exists-p ref-state))
                          (ref-state-symbolic-p ref-state)))
         (marker (unless invalid-ref
                   (committed-state-marker-p directory source-ref)))
         (related (or marker registration))
         (state (when (and related (not invalid-ref))
                  (inspect-committed-state directory source-ref)))
         (object-id
           (if state
               (committed-state-report-commit-oid state)
               (ref-state-object-id ref-state))))
    (%make-status-branch
     source-ref object-id
     (cond (invalid-ref :invalid)
           ((not related) :ordinary)
           ((committed-state-report-ok-p state) :valid)
           (t :invalid))
     (if registration
         (status-protocol-ref-status registration)
         :missing)
     state)))

(defun %status-selector (ref protocol-refs registration-prefix source-prefix
                         branches)
  (let ((kind (status-protocol-ref-kind ref))
        (value (status-protocol-ref-value ref)))
    (cond
      ((eq kind :missing) ref)
      ((eq kind :unreadable) ref)
      ((eq kind :direct)
       (%make-status-protocol-ref (status-protocol-ref-name ref)
                                  kind value :invalid
                                  "Selector must be symbolic"))
      ((or (null value)
           (not (%status-registration-ref-p value registration-prefix)))
       (%make-status-protocol-ref (status-protocol-ref-name ref)
                                  kind value :invalid
                                  "Selector target is not a registration"))
      (t
       (let* ((registration
                (find value protocol-refs :test #'string=
                      :key #'status-protocol-ref-name))
              (source (%status-source-for-registration
                       value registration-prefix source-prefix))
              (branch (find source branches :test #'string=
                            :key #'status-branch-ref)))
         (if (and registration
                  (eq :exact (status-protocol-ref-status registration))
                  branch
                  (eq :valid (status-branch-classification branch)))
             (%make-status-protocol-ref (status-protocol-ref-name ref)
                                        kind value :valid "")
             (%make-status-protocol-ref (status-protocol-ref-name ref)
                                        kind value :invalid
                                        "Selector does not reach a valid registered GAW branch")))))))

(defun %status-runtime (directory source-prefix registration-prefix
                        protocol-prefix selector-ref)
  (let ((repository (%status-repository directory)))
    (handler-case
        (let* ((source-refs (sort (local-branches directory) #'string<))
               (enumerated-refs (protocol-refs directory))
               (raw-selector (%status-inspect-protocol-ref selector-ref
                                                           directory))
               (protocol-names
                 (%status-ref-names source-refs enumerated-refs raw-selector
                                    source-prefix registration-prefix
                                    protocol-prefix))
               (raw-protocol-refs
                 (loop for name in protocol-names
                       for ref = (if (string= name selector-ref)
                                     raw-selector
                                     (%status-inspect-protocol-ref name
                                                                   directory))
                       unless (and (eq :missing
                                       (status-protocol-ref-kind ref))
                                   (not (member name enumerated-refs
                                                :test #'string=)))
                         collect (if (eq :missing
                                         (status-protocol-ref-kind ref))
                                     (%make-status-protocol-ref
                                      name :unreadable nil :unreadable
                                      "Enumerated ref disappeared during inspection")
                                     ref)))
               (protocol-refs
                 (mapcar (lambda (ref)
                           (%status-classify-protocol-ref
                            ref source-refs registration-prefix
                            source-prefix selector-ref))
                         raw-protocol-refs))
               (branches
                 (mapcar
                  (lambda (source-ref)
                    (let* ((name
                             (concatenate 'string registration-prefix
                                          (subseq source-ref
                                                  (length source-prefix))))
                           (registration
                             (find name protocol-refs :test #'string=
                                   :key #'status-protocol-ref-name)))
                      (%status-branch-report source-ref directory registration)))
                  source-refs))
               (selector
                 (%status-selector
                  (or (find selector-ref protocol-refs :test #'string=
                            :key #'status-protocol-ref-name)
                      raw-selector)
                  protocol-refs registration-prefix source-prefix branches))
               (classified-protocol-refs
                 (mapcar (lambda (ref)
                           (if (string= (status-protocol-ref-name ref)
                                        selector-ref)
                               selector
                               ref))
                         protocol-refs))
               (worktrees (list-worktrees directory))
               (hook (inspect-protection-hook directory)))
          (%make-status-report repository branches classified-protocol-refs
                               selector worktrees hook))
      (status-error (condition)
        (error condition))
      (error (condition)
        (%signal-status-error :query-failed "~A" condition)))))

(defun %diagnose-status (directory arguments)
  (git-invocation-exit-status
   (run-git-passthrough arguments directory)))
