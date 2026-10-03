(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status
                      %make-ref-state
                      %make-ref
                      %registration-state-registered-p
                      %ref-state-dangling-p
                      %ensure-registration-available
                      %validate-target-ref
                      %ensure-registration-removable
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

(defun %select-ref (source-ref directory source-ref-prefix
                    target-ref-prefix head-ref git-options)
  (unless (%ref-under-prefix-p source-ref source-ref-prefix)
    (error "Not a local source branch ref: ~S" source-ref))
  (let* ((source-state (inspect-ref source-ref directory))
         (registration-ref
           (%make-ref source-ref source-ref-prefix target-ref-prefix))
         (registration-state (inspect-ref registration-ref directory))
         (head-state (inspect-ref head-ref directory)))
    (unless (and (ref-state-exists-p source-state)
                 (not (ref-state-symbolic-p source-state)))
      (error "GAW source branch is missing or symbolic: ~S" source-ref))
    (%registration-state-registered-p registration-state source-ref)
    (when (and (ref-state-exists-p head-state)
               (not (ref-state-symbolic-p head-state)))
      (error 'registration-error
             :reason :direct-registration
             :ref head-ref))
    (when (and (ref-state-exists-p head-state)
               (not (%ref-under-prefix-p
                     (ref-state-symbolic-target head-state)
                     target-ref-prefix)))
      (error 'registration-error
             :reason :target-mismatch
             :ref head-ref
             :target (ref-state-symbolic-target head-state)))
    (let ((commands '()))
      (unless (ref-state-exists-p registration-state)
        (push (%symref-create-command registration-ref source-ref) commands))
      (cond
        ((not (ref-state-exists-p head-state))
         (push (%symref-create-command head-ref registration-ref) commands))
        ((not (string= (ref-state-symbolic-target head-state)
                       registration-ref))
         (push (%symref-update-command
                head-ref registration-ref :ref
                (ref-state-symbolic-target head-state))
               commands)))
      (when commands
        (apply-ref-transaction (nreverse commands)
                               directory
                               :reflog-message "git-gaw select"
                               :git-options git-options))
      (%make-selection-change
       source-ref registration-ref
       (not (ref-state-exists-p registration-state))
       head-ref
       (and (ref-state-exists-p head-state)
            (ref-state-symbolic-target head-state))
       registration-ref))))

(defun %restore-selection (change directory git-options)
  (check-type change selection-change)
  (let ((commands '()))
    (if (selection-change-old-head-target change)
        (unless (string=
                 (selection-change-old-head-target change)
                 (selection-change-new-head-target change))
          (push (%symref-update-command
                 (selection-change-head-ref change)
                 (selection-change-old-head-target change)
                 :ref
                 (selection-change-new-head-target change))
                commands))
        (push (%symref-delete-command
               (selection-change-head-ref change)
               (selection-change-new-head-target change))
              commands))
    (when (selection-change-registration-created-p change)
      (push (%symref-delete-command
             (selection-change-registration-ref change)
             (selection-change-source-ref change))
            commands))
    (when commands
      (apply-ref-transaction (nreverse commands)
                             directory
                             :reflog-message "git-gaw deploy rollback"
                             :git-options git-options))
    t))

(defun %initialize-ref-graph (source-ref object-id directory
                              source-ref-prefix target-ref-prefix head-ref
                              git-options)
  (unless (%ref-under-prefix-p source-ref source-ref-prefix)
    (error "Not a local source branch ref: ~S" source-ref))
  (let ((registration-ref
          (%make-ref source-ref source-ref-prefix target-ref-prefix)))
    (dolist (ref (list source-ref registration-ref head-ref))
      (when (ref-state-exists-p (inspect-ref ref directory))
        (error "Cannot initialize an existing ref: ~S" ref)))
    (apply-ref-transaction
     (list (%create-command source-ref object-id)
           (%symref-create-command registration-ref source-ref)
           (%symref-create-command head-ref registration-ref))
     directory
     :reflog-message "git-gaw init"
     :git-options git-options)
    source-ref))

(defun %remove-initial-ref-graph (source-ref object-id directory
                                  source-ref-prefix target-ref-prefix head-ref
                                  git-options)
  (let ((registration-ref
          (%make-ref source-ref source-ref-prefix target-ref-prefix)))
    (apply-ref-transaction
     (list (%symref-delete-command head-ref registration-ref)
           (%symref-delete-command registration-ref source-ref)
           (%delete-command source-ref object-id))
     directory
     :reflog-message "git-gaw init rollback"
     :git-options git-options)
    t))

(defun %rename-ref-registration (old-source-ref new-source-ref directory
                                 source-ref-prefix target-ref-prefix head-ref
                                 git-options)
  (let* ((old-registration
           (%make-ref old-source-ref source-ref-prefix target-ref-prefix))
         (new-registration
           (%make-ref new-source-ref source-ref-prefix target-ref-prefix))
         (old-state (inspect-ref old-registration directory))
         (new-state (inspect-ref new-registration directory))
         (head-state (inspect-ref head-ref directory)))
    (unless (%registration-state-registered-p old-state old-source-ref)
      (error "Registration does not exist: ~S" old-registration))
    (when (ref-state-exists-p new-state)
      (error "Destination registration already exists: ~S" new-registration))
    (unless (and (ref-state-exists-p head-state)
                 (ref-state-symbolic-p head-state)
                 (string= old-registration
                          (ref-state-symbolic-target head-state)))
      (error "refs/gaw/HEAD does not select ~S" old-registration))
    (apply-ref-transaction
     (list (%symref-delete-command old-registration old-source-ref)
           (%symref-create-command new-registration new-source-ref)
           (%symref-update-command head-ref new-registration
                                   :ref old-registration))
     directory
     :reflog-message "git-gaw branch rename"
     :git-options git-options)
    new-registration))

(defun %remove-ref-registration (source-ref directory
                                 source-ref-prefix target-ref-prefix head-ref
                                 git-options)
  (let* ((registration-ref
           (%make-ref source-ref source-ref-prefix target-ref-prefix))
         (registration-state (inspect-ref registration-ref directory))
         (head-state (inspect-ref head-ref directory)))
    (unless (%registration-state-registered-p registration-state source-ref)
      (error "Registration does not exist: ~S" registration-ref))
    (when (and (ref-state-exists-p head-state)
               (not (ref-state-symbolic-p head-state)))
      (error "refs/gaw/HEAD is not symbolic"))
    (let ((selected-p
            (and (ref-state-exists-p head-state)
                 (string= registration-ref
                          (ref-state-symbolic-target head-state))))
          (commands
            (list (%symref-delete-command registration-ref source-ref))))
      (when selected-p
        (push (%symref-delete-command head-ref registration-ref) commands))
      (apply-ref-transaction (nreverse commands) directory
                             :reflog-message "git-gaw branch delete"
                             :git-options git-options)
      (%make-registration-removal
       source-ref registration-ref head-ref selected-p))))

(defun %restore-ref-registration (removal directory git-options)
  (check-type removal registration-removal)
  (let ((commands
          (list (%symref-create-command
                 (registration-removal-registration-ref removal)
                 (registration-removal-source-ref removal)))))
    (when (registration-removal-selected-p removal)
      (push (%symref-create-command
             (registration-removal-head-ref removal)
             (registration-removal-registration-ref removal))
            commands))
    (apply-ref-transaction (nreverse commands) directory
                           :reflog-message "git-gaw branch delete rollback"
                           :git-options git-options)
    t))

(defun %registered-ref-p (source-ref
                          directory
                          source-ref-prefix
                          target-ref-prefix)
  (let ((registration-ref
          (%make-ref source-ref
                     source-ref-prefix
                     target-ref-prefix)))
    (%registration-state-registered-p
     (inspect-ref registration-ref directory)
     source-ref)))

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
         (%ref-state-dangling-p
          ref-state
          (inspect-ref (ref-state-symbolic-target ref-state)
                       directory)))))

(defun %register-ref (source-ref
                      directory
                      overwrite
                      display-name
                      source-ref-prefix
                      target-ref-prefix
                      git-options)
  (let* ((target-ref (%make-ref source-ref
                                source-ref-prefix
                                target-ref-prefix))
         (target-state (inspect-ref target-ref
                                    directory)))
    (%ensure-registration-available target-state
                                    overwrite
                                    display-name
                                    target-ref)
    (apply-ref-transaction
     (list (cond
             ((not (ref-state-exists-p target-state))
              (%symref-create-command target-ref source-ref))
             ((ref-state-symbolic-p target-state)
              (%symref-update-command
               target-ref source-ref :ref
               (ref-state-symbolic-target target-state)))
             (t
              (%symref-update-command
               target-ref source-ref :oid
               (ref-state-object-id target-state)))))
     directory
     :reflog-message "git-gaw register"
     :git-options git-options)
    target-ref))

(defun %unregister-ref (target-ref
                        directory
                        display-name
                        target-ref-prefix
                        git-options)
  (%validate-target-ref target-ref
                        target-ref-prefix)
  (let ((target-state (inspect-ref target-ref
                                   directory)))
    (%ensure-registration-removable target-state
                                    display-name
                                    target-ref)
    (apply-ref-transaction
     (list (%symref-delete-command
            target-ref
            (ref-state-symbolic-target target-state)))
     directory
     :reflog-message "git-gaw unregister"
     :git-options git-options)
    target-ref))
