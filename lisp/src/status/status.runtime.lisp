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

(defun %status-protocol-kind (state)
  (cond ((not (ref-state-exists-p state)) :missing)
        ((ref-state-symbolic-p state) :symbolic)
        (t :direct)))

(defun %status-ref-value (state)
  (if (ref-state-symbolic-p state)
      (ref-state-symbolic-target state)
      (ref-state-object-id state)))

(defun %status-inspect-protocol-ref (name directory)
  (handler-case
      (let* ((state (inspect-ref name directory))
             (kind (%status-protocol-kind state)))
        (%make-status-protocol-ref
         name kind (%status-ref-value state)
         (if (eq kind :missing) :missing :unclassified) ""))
    (error (condition)
      (%make-status-protocol-ref name :unreadable nil :unreadable
                                 (princ-to-string condition)))))

(defun %status-branch-report (source-ref directory)
  (let* ((state (inspect-ref source-ref directory))
         (invalid-ref (or (not (ref-state-exists-p state))
                          (ref-state-symbolic-p state)))
         (marker (unless invalid-ref
                   (committed-state-marker-p directory source-ref)))
         (report (when (and marker (not invalid-ref))
                   (inspect-committed-state directory source-ref))))
    (%make-status-branch
     source-ref (ref-state-object-id state)
     (cond (invalid-ref :invalid)
           ((not marker) :ordinary)
           ((committed-state-report-ok-p report) :valid)
           (t :invalid))
     report)))

(defun %status-selector (selector branches source-prefix)
  (let ((kind (status-protocol-ref-kind selector))
        (target (status-protocol-ref-value selector)))
    (cond
      ((member kind '(:missing :unreadable)) selector)
      ((not (eq kind :symbolic))
       (%make-status-protocol-ref (status-protocol-ref-name selector)
                                  kind target :invalid
                                  "Selector must be symbolic"))
      ((or (null target)
           (not (uiop:string-prefix-p source-prefix target)))
       (%make-status-protocol-ref (status-protocol-ref-name selector)
                                  kind target :invalid
                                  "Selector must point directly to a local branch"))
      (t
       (let ((branch (find target branches :test #'string=
                           :key #'status-branch-ref)))
         (%make-status-protocol-ref
          (status-protocol-ref-name selector) kind target
          (if (and branch
                   (eq :valid (status-branch-classification branch)))
              :valid :invalid)
          (if (and branch
                   (eq :valid (status-branch-classification branch)))
              "" "Selector does not reach a valid GAW branch")))))))

(defun %status-protocol-names (source-refs enumerated selector
                               source-prefix protocol-prefix legacy-prefix)
  (let ((target (status-protocol-ref-value selector)))
    (sort (remove-duplicates
           (append enumerated
                   (when (and (eq :symbolic
                                  (status-protocol-ref-kind selector))
                              target
                              (uiop:string-prefix-p protocol-prefix target))
                     (list target))
                   (loop for source in source-refs
                         collect (concatenate
                                  'string legacy-prefix
                                  (subseq source (length source-prefix)))))
           :test #'string=)
          #'string<)))

(defun %status-runtime (directory source-prefix protocol-prefix
                        legacy-prefix selector-ref)
  (let ((repository (%status-repository directory)))
    (handler-case
        (let* ((source-refs (sort (local-branches directory) #'string<))
               (branches (mapcar (lambda (ref)
                                   (%status-branch-report ref directory))
                                 source-refs))
               (raw-selector (%status-inspect-protocol-ref selector-ref
                                                           directory))
               (selector (%status-selector raw-selector branches
                                           source-prefix))
               (enumerated (protocol-refs directory))
               (names (%status-protocol-names source-refs enumerated
                                               raw-selector source-prefix
                                               protocol-prefix legacy-prefix))
               (other-refs
                 (loop for name in names
                       for ref = (%status-inspect-protocol-ref name directory)
                       unless (string= name selector-ref)
                         unless (and (eq :missing
                                         (status-protocol-ref-kind ref))
                                     (not (member name enumerated
                                                  :test #'string=)))
                           collect (if (eq :missing
                                           (status-protocol-ref-kind ref))
                                       (%make-status-protocol-ref
                                        name :unreadable nil :unreadable
                                        "Enumerated ref disappeared")
                                       (%make-status-protocol-ref
                                        name (status-protocol-ref-kind ref)
                                        (status-protocol-ref-value ref)
                                        (if (eq :unreadable
                                                (status-protocol-ref-kind ref))
                                            :unreadable :unknown)
                                        (if (eq :unreadable
                                                (status-protocol-ref-kind ref))
                                            (status-protocol-ref-detail ref)
                                            "Unexpected GAW protocol ref")))))
               (refs (if (eq :missing (status-protocol-ref-kind selector))
                         other-refs (cons selector other-refs)))
               (worktrees (list-worktrees directory))
               (hook (inspect-protection-hook directory)))
          (%make-status-report repository branches refs selector
                               worktrees hook))
      (status-error (condition) (error condition))
      (error (condition)
        (%signal-status-error :query-failed "~A" condition)))))

(defun %diagnose-status (directory arguments)
  (git-invocation-exit-status
   (run-git-passthrough arguments directory)))
