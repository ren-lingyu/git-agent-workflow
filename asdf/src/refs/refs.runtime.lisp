(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status
                      %make-ref-state
                      %transaction-command-octets
                      %symref-create-command
                      %symref-update-command
                      %symref-delete-command
                      %create-command
                      %delete-command))
    (unless (fboundp function)
      (error "Required runtime dependency is unavailable: ~S"
             function))))

(defun apply-ref-transaction (commands directory
                              &key (reflog-message "git-gaw refs")
                                git-options)
  (check-type reflog-message string)
  (check-type git-options list)
  (let ((invocation
          (run-git (append git-options
                           (list "update-ref"
                                 "-m"
                                 reflog-message
                                 "--stdin"
                                 "-z"))
                   directory
                   :input (%transaction-command-octets commands))))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Failed to update GAW refs: ~A"
             (git-invocation-stderr invocation)))
    t))

(defun %list-refs (prefix directory)
  (let ((invocation
          (run-git (list "for-each-ref" "--format=%(refname)" prefix)
                   directory)))
    (unless (zerop (git-invocation-exit-status invocation))
      (error "Failed to list Git refs under ~S: ~A"
             prefix
             (git-invocation-stderr invocation)))
    (let ((output (git-invocation-stdout invocation)))
      (if (zerop (length output))
          '()
          (uiop:split-string output :separator '(#\Newline))))))

(defun %ref-exists-p (checked-ref directory)
  (let ((invocation (run-git (list "show-ref"
                                   "--exists"
                                   checked-ref)
                             directory)))
    (case (git-invocation-exit-status invocation)
      (0
       t)
      (2
       nil)
      (otherwise
       (error "Failed to check Git ref ~S: ~A"
              checked-ref
              (git-invocation-stderr invocation))))))

(defun inspect-ref (checked-ref directory)
  (check-type checked-ref
              string)
  (if (not (%ref-exists-p checked-ref
                          directory))
      (%make-ref-state :name checked-ref
                       :exists-p nil)
      (let ((invocation (run-git (list "symbolic-ref"
                                       "--quiet"
                                       "--no-recurse"
                                       checked-ref)
                                 directory)))
        (case (git-invocation-exit-status invocation)
          (0
           (%make-ref-state
            :name checked-ref
            :exists-p t
            :symbolic-p t
            :symbolic-target
            (git-invocation-stdout invocation)))
          (1
           (let ((object-invocation
                   (run-git (list "rev-parse"
                                  "--verify"
                                  "--end-of-options"
                                  checked-ref)
                            directory)))
             (unless (zerop (git-invocation-exit-status object-invocation))
               (error "Failed to resolve direct Git ref ~S: ~A"
                      checked-ref
                      (git-invocation-stderr object-invocation)))
             (%make-ref-state :name checked-ref
                              :exists-p t
                              :symbolic-p nil
                              :object-id
                              (git-invocation-stdout object-invocation))))
          (otherwise
           (error "Failed to inspect Git ref ~S: ~A"
                  checked-ref
                  (git-invocation-stderr invocation)))))))

(defun ref-dangling-p (checked-ref directory)
  (let ((ref-state (inspect-ref checked-ref
                                directory)))
    (and (ref-state-exists-p ref-state)
         (ref-state-symbolic-p ref-state)
         (not (ref-state-exists-p
               (inspect-ref (ref-state-symbolic-target ref-state)
                            directory))))))

(defun %select-source-ref (source-ref directory source-prefix head-ref
                           git-options)
  (unless (%ref-under-prefix-p source-ref source-prefix)
    (error "Not a local source branch ref: ~S" source-ref))
  (let ((source (inspect-ref source-ref directory))
        (head (inspect-ref head-ref directory)))
    (unless (and (ref-state-exists-p source)
                 (not (ref-state-symbolic-p source)))
      (error "GAW source branch is missing or symbolic: ~S" source-ref))
    (when (and (ref-state-exists-p head)
               (not (ref-state-symbolic-p head)))
      (error "GAW selector is not symbolic: ~S" head-ref))
    (when (and (ref-state-exists-p head)
               (not (%ref-under-prefix-p
                     (ref-state-symbolic-target head) source-prefix)))
      (error "GAW selector has an invalid target: ~S" head-ref))
    (let ((old (and (ref-state-exists-p head)
                    (ref-state-symbolic-target head))))
      (unless (equal old source-ref)
        (apply-ref-transaction
         (list (if old
                   (%symref-update-command head-ref source-ref :ref old)
                   (%symref-create-command head-ref source-ref)))
         directory :reflog-message "git-gaw select"
                   :git-options git-options))
      (%make-selector-change head-ref old source-ref))))

(defun %restore-source-selection (change directory git-options)
  (check-type change selector-change)
  (unless (equal (selector-change-old-target change)
                 (selector-change-new-target change))
    (apply-ref-transaction
     (list (if (selector-change-old-target change)
               (%symref-update-command
                (selector-change-head-ref change)
                (selector-change-old-target change)
                :ref (selector-change-new-target change))
               (%symref-delete-command
                (selector-change-head-ref change)
                (selector-change-new-target change))))
     directory :reflog-message "git-gaw deploy rollback"
               :git-options git-options))
  t)

(defun %initialize-source-and-selector (source-ref object-id directory
                                        source-prefix head-ref git-options)
  (unless (%ref-under-prefix-p source-ref source-prefix)
    (error "Not a local source branch ref: ~S" source-ref))
  (dolist (ref (list source-ref head-ref))
    (when (ref-state-exists-p (inspect-ref ref directory))
      (error "Cannot initialize an existing ref: ~S" ref)))
  (apply-ref-transaction
   (list (%create-command source-ref object-id)
         (%symref-create-command head-ref source-ref))
   directory :reflog-message "git-gaw init" :git-options git-options)
  source-ref)

(defun %remove-initial-source-and-selector (source-ref object-id directory
                                            head-ref git-options)
  (apply-ref-transaction
   (list (%symref-delete-command head-ref source-ref)
         (%delete-command source-ref object-id))
   directory :reflog-message "git-gaw init rollback"
             :git-options git-options)
  t)

(defun %rename-selected-source (old-source-ref new-source-ref directory
                                head-ref git-options)
  (let ((head (inspect-ref head-ref directory)))
    (unless (and (ref-state-exists-p head)
                 (ref-state-symbolic-p head)
                 (string= old-source-ref
                          (ref-state-symbolic-target head)))
      (error "GAW selector does not select ~S" old-source-ref))
    (apply-ref-transaction
     (list (%symref-update-command head-ref new-source-ref
                                   :ref old-source-ref))
     directory :reflog-message "git-gaw branch rename"
               :git-options git-options)
    new-source-ref))

(defun %delete-selector (directory head-ref git-options)
  (let ((state (inspect-ref head-ref directory)))
    (when (ref-state-exists-p state)
      (apply-ref-transaction
       (list (if (ref-state-symbolic-p state)
                 (%symref-delete-command
                  head-ref (ref-state-symbolic-target state))
                 (concatenate 'string
                              (format nil "option no-deref~C" #\Null)
                              (%delete-command head-ref
                                               (ref-state-object-id state)))))
       directory :reflog-message "git-gaw undeploy"
                 :git-options git-options)))
  t)

(defun %delete-symbolic-ref (ref target directory git-options)
  (apply-ref-transaction
   (list (%symref-delete-command ref target)) directory
   :reflog-message "git-gaw undeploy legacy registration"
   :git-options git-options))
