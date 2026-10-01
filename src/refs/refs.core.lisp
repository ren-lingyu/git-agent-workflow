(in-package #:git-agent-workflow.refs)

(defstruct (ref-state (:constructor %make-ref-state))
  name
  exists-p
  symbolic-p
  symbolic-target
  object-id)

(defstruct (selection-change
            (:constructor %make-selection-change
                (source-ref registration-ref registration-created-p
                 head-ref old-head-target new-head-target))
            (:copier nil))
  (source-ref "" :type string :read-only t)
  (registration-ref "" :type string :read-only t)
  (registration-created-p nil :type boolean :read-only t)
  (head-ref "" :type string :read-only t)
  (old-head-target nil :type (or null string) :read-only t)
  (new-head-target "" :type string :read-only t))

(defstruct (registration-removal
            (:constructor %make-registration-removal
                (source-ref registration-ref head-ref selected-p))
            (:copier nil))
  (source-ref "" :type string :read-only t)
  (registration-ref "" :type string :read-only t)
  (head-ref "" :type string :read-only t)
  (selected-p nil :type boolean :read-only t))

(defun %transaction-command-octets (commands)
  (unless (and (listp commands)
               (every #'stringp commands))
    (error 'type-error :datum commands :expected-type 'list))
  (babel:string-to-octets
   (with-output-to-string (stream)
     (dolist (command commands)
       (write-string command stream)))
   :encoding :utf-8))

(defun %z-field (value)
  (check-type value string)
  (when (find #\Null value)
    (error "NUL is not allowed in a Git ref transaction field"))
  value)

(defun %symref-create-command (ref target)
  (format nil "option no-deref~Csymref-create ~A~C~A~C"
          #\Null
          (%z-field ref) #\Null (%z-field target) #\Null))

(defun %symref-update-command (ref target old-kind old-value)
  (unless (member old-kind '(:ref :oid))
    (error "Invalid symbolic ref expected-old kind: ~S" old-kind))
  (format nil "option no-deref~Csymref-update ~A~C~A~C~(~A~)~C~A~C"
          #\Null
          (%z-field ref) #\Null
          (%z-field target) #\Null
          old-kind #\Null
          (%z-field old-value) #\Null))

(defun %symref-delete-command (ref old-target)
  (format nil "option no-deref~Csymref-delete ~A~C~A~C"
          #\Null
          (%z-field ref) #\Null (%z-field old-target) #\Null))

(defun %create-command (ref object-id)
  (format nil "create ~A~C~A~C"
          (%z-field ref) #\Null (%z-field object-id) #\Null))

(defun %delete-command (ref old-object-id)
  (format nil "delete ~A~C~A~C"
          (%z-field ref) #\Null (%z-field old-object-id) #\Null))

(define-condition registration-error (error)
  ((reason :initarg :reason
           :reader registration-error-reason)
   (ref :initarg :ref
        :reader registration-error-ref)
   (target :initarg :target
           :initform nil
           :reader registration-error-target))
  (:report (lambda (condition stream)
             (case (registration-error-reason condition)
               (:direct-registration
                (format stream
                        "GAW branch registration is not a symbolic ref: ~S"
                        (registration-error-ref condition)))
               (:target-mismatch
                (format stream
                        "GAW branch registration ~S points to the wrong ref: ~S"
                        (registration-error-ref condition)
                        (registration-error-target condition)))
               (otherwise
                (format stream
                        "Invalid GAW branch registration: ~S"
                        (registration-error-ref condition)))))))

(defun %ref-under-prefix-p (checked-ref prefix)
  (and (> (length checked-ref)
          (length prefix))
       (string= prefix
                checked-ref
                :end2 (length prefix))))

(defun %make-ref (source-ref source-ref-prefix target-ref-prefix)
  (check-type source-ref
              string)
  (unless (%ref-under-prefix-p source-ref
                               source-ref-prefix)
    (error "Not a valid source ref: ~S"
           source-ref))
  (concatenate 'string
               target-ref-prefix
               (subseq source-ref
                       (length source-ref-prefix))))

(defun %ref-state-dangling-p (ref-state target-state)
  (and (ref-state-exists-p ref-state)
       (ref-state-symbolic-p ref-state)
       (not (ref-state-exists-p target-state))))

(defun %registration-state-registered-p (registration-state source-ref)
  (cond
    ((not (ref-state-exists-p registration-state))
     nil)
    ((not (ref-state-symbolic-p registration-state))
     (error 'registration-error
            :reason :direct-registration
            :ref (ref-state-name registration-state)))
    ((not (string= source-ref
                   (ref-state-symbolic-target registration-state)))
     (error 'registration-error
            :reason :target-mismatch
            :ref (ref-state-name registration-state)
            :target (ref-state-symbolic-target registration-state)))
    (t
     t)))

(defun %ensure-registration-available (target-state
                                       overwrite
                                       display-name
                                       target-ref)
  (when (and (not overwrite)
             (ref-state-exists-p target-state))
    (error "~A branch registration already exists: ~S"
           display-name
           target-ref))
  target-ref)

(defun %validate-target-ref (target-ref target-ref-prefix)
  (check-type target-ref
              string)
  (unless (%ref-under-prefix-p target-ref
                               target-ref-prefix)
    (error "Not a valid target ref: ~S"
           target-ref))
  target-ref)

(defun %ensure-registration-removable (target-state
                                       display-name
                                       target-ref)
  (unless (ref-state-exists-p target-state)
    (error "~A branch registration does not exist: ~S"
           display-name
           target-ref))
  (unless (ref-state-symbolic-p target-state)
    (error "~A branch registration is not a symbolic ref: ~S"
           display-name
           target-ref))
  target-ref)
