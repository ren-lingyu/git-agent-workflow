(in-package #:git-agent-workflow.hook)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%reference-transaction-phase
                      %parse-reference-transaction-line
                      %signal-hook-error
                      %make-hook-configuration
                      %signal-hook-configuration-error
                      run-git
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status))
    (unless (fboundp function)
      (error "Required hook runtime dependency is unavailable: ~S"
             function))))

(defun %local-config-values (key directory &key boolean)
  (let ((arguments (append (list "config" "--local")
                           (when boolean (list "--type=bool"))
                           (list "--get-all" key))))
    (let ((invocation (run-git arguments directory)))
      (case (git-invocation-exit-status invocation)
        (0
         (let ((output (git-invocation-stdout invocation)))
           (if (zerop (length output))
               (list "")
               (uiop:split-string output :separator '(#\Newline)))))
        (1
         nil)
        (otherwise
         (%signal-hook-configuration-error
          :query-failed
          "Cannot read local Git config ~S: ~A"
          key
          (git-invocation-stderr invocation)))))))

(defun %inspect-protection-hook (directory
                                 event-key command-key enabled-key
                                 expected-event expected-command)
  (let ((events (%local-config-values event-key directory))
        (commands (%local-config-values command-key directory))
        (enabled (%local-config-values enabled-key directory :boolean t)))
    (cond
      ((and (null events) (null commands) (null enabled))
       (%make-hook-configuration :absent
                                 "The GAW protection hook is not configured"))
      ((and (equal events (list expected-event))
            (equal commands (list expected-command))
            (equal enabled '("true")))
       (%make-hook-configuration :canonical
                                 "The GAW protection hook is configured"))
      (t
       (%make-hook-configuration
        :conflict
        "The gaw-reference-transaction hook configuration is incomplete or divergent")))))

(defun %set-local-config (key value directory)
  (let ((invocation (run-git (list "config" "--local" key value)
                             directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (%signal-hook-configuration-error
       :installation-failed
       "Cannot set local Git config ~S: ~A"
       key
       (git-invocation-stderr invocation)))))

(defun %unset-local-config (key directory)
  (let ((invocation (run-git (list "config" "--local" "--unset-all" key)
                             directory)))
    (member (git-invocation-exit-status invocation) '(0 1 5))))

(defun %remove-protection-hook (directory keys)
  (let ((failed '()))
    (dolist (key keys)
      (unless (%unset-local-config key directory)
        (push key failed)))
    (when failed
      (%signal-hook-configuration-error
       :removal-failed "Cannot remove local hook keys: ~{~A~^, ~}"
       (nreverse failed)))
    t))

(defun %ensure-protection-hook (directory
                                event-key command-key enabled-key
                                expected-event expected-command)
  (let ((configuration
          (%inspect-protection-hook directory
                                    event-key command-key enabled-key
                                    expected-event expected-command)))
    (case (hook-configuration-status configuration)
      (:canonical
       :existing)
      (:conflict
       (%signal-hook-configuration-error
        :conflict
        "~A"
        (hook-configuration-detail configuration)))
      (:absent
       (let ((written '()))
         (handler-case
             (progn
               (dolist (entry (list (cons command-key expected-command)
                                    (cons event-key expected-event)
                                    (cons enabled-key "true")))
                 (%set-local-config (car entry) (cdr entry) directory)
                 (push (car entry) written))
               :installed)
           (error (condition)
             (unless (every (lambda (key)
                              (%unset-local-config key directory))
                            written)
               (%signal-hook-configuration-error
                :partial-installation
                "Hook installation failed and rollback was incomplete: ~A"
                condition))
             (error condition))))))))

(defun %resolve-symbolic-source-ref (ref directory source-ref-prefix)
  (let ((seen (make-hash-table :test #'equal))
        (current ref))
    (loop
      (when (gethash current seen)
        (error "Symbolic ref cycle while resolving ~S" ref))
      (setf (gethash current seen) t)
      (let ((state (inspect-ref current directory)))
        (unless (and (ref-state-exists-p state)
                     (ref-state-symbolic-p state))
          (return nil))
        (let ((target (ref-state-symbolic-target state)))
          (when (%ref-under-prefix-p target source-ref-prefix)
            (return target))
          (setf current target))))))

(defun %source-ref-for-transaction-ref (update directory source-ref-prefix)
  (let ((transaction-ref (%reference-update-ref update)))
    (cond
      ((%ref-under-prefix-p transaction-ref source-ref-prefix)
       transaction-ref)
      ((%reference-update-symbolic-p update)
       nil)
      (t
       (%resolve-symbolic-source-ref transaction-ref
                                     directory source-ref-prefix)))))

(defun %source-ref-for-hook (update
                             directory
                             source-ref-resolver)
  (handler-case
      (funcall source-ref-resolver update directory)
    (error (condition)
      (%signal-hook-error :state-query-failure
                          :ref (%reference-update-ref update)
                          :detail (princ-to-string condition)
                          :cause condition))))

(defun %zero-object-id-p (value)
  (and (plusp (length value))
       (every (lambda (character) (char= character #\0)) value)))

(defun %protect-source-update (update source-ref directory ref-query
                               marker-query state-query classification-query)
  (handler-case
      (let ((state (funcall ref-query source-ref directory))
            (new-value (%reference-update-new-value update)))
        (when (ref-state-exists-p state)
          (when (ref-state-symbolic-p state)
            (%signal-hook-error :state-query-failure :ref source-ref
                                :detail "Source branch is symbolic"))
          (let* ((old-oid (ref-state-object-id state))
                 (old-marker (funcall marker-query directory old-oid)))
            (when old-marker
              (case (funcall classification-query
                             (funcall state-query directory old-oid))
                (:valid
                 (unless (string= old-oid new-value)
                   (%signal-hook-error :protected-ref :ref source-ref)))
                (:indeterminate
                 (%signal-hook-error :state-query-failure :ref source-ref
                                     :detail "Old committed state is indeterminate"))))
            (when (and old-marker (not (string= old-oid new-value)))
              (let ((new-marker
                      (unless (or (%zero-object-id-p new-value)
                                  (%symbolic-transaction-value-p new-value))
                        (funcall marker-query directory new-value))))
                (unless (equal old-marker new-marker)
                  (%signal-hook-error :protected-marker :ref source-ref)))))))
    (hook-error (condition) (error condition))
    (error (condition)
      (%signal-hook-error :state-query-failure :ref source-ref
                          :detail (princ-to-string condition)
                          :cause condition))))

(defun %preparing-reference-transaction (directory
                                         input-stream
                                         source-ref-resolver
                                         ref-query marker-query
                                         state-query classification-query
                                         protocol-ref-prefix)
  (loop for line = (read-line input-stream nil nil)
        while line
        for update = (%parse-reference-transaction-line line)
        for transaction-ref = (%reference-update-ref update)
        do (when (%ref-under-prefix-p transaction-ref protocol-ref-prefix)
             (%signal-hook-error :protected-protocol-ref
                                 :ref transaction-ref))
           (let ((source-ref (%source-ref-for-hook
                              update directory source-ref-resolver)))
             (when source-ref
               (%protect-source-update update source-ref directory
                                       ref-query marker-query state-query
                                       classification-query))))
  t)

(defun %reference-transaction (phase
                               directory
                               input-stream
                               source-ref-resolver
                               ref-query marker-query
                               state-query classification-query
                               protocol-ref-prefix)
  (case (%reference-transaction-phase phase)
    (:preparing
     (%preparing-reference-transaction directory
                                       input-stream
                                       source-ref-resolver
                                       ref-query marker-query
                                       state-query classification-query
                                       protocol-ref-prefix))
    ((:prepared :committed :aborted)
     t)))
