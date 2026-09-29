(in-package #:git-agent-workflow.refs)

(defstruct (ref-state (:constructor %make-ref-state))
  name
  exists-p
  symbolic-p
  symbolic-target)

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
