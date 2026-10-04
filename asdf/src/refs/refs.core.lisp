(in-package #:git-agent-workflow.refs)

(defstruct (ref-state (:constructor %make-ref-state))
  name
  exists-p
  symbolic-p
  symbolic-target
  object-id)

(defstruct (selector-change
            (:constructor %make-selector-change
                (head-ref old-target new-target))
            (:copier nil))
  (head-ref "" :type string :read-only t)
  (old-target nil :type (or null string) :read-only t)
  (new-target "" :type string :read-only t))

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

(defun %ref-under-prefix-p (checked-ref prefix)
  (and (> (length checked-ref)
          (length prefix))
       (string= prefix
                checked-ref
                :end2 (length prefix))))
