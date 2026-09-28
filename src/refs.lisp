(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status))
    (unless (fboundp function)
      (error "Required Git function is unavailable: ~S"
             function))))

(defparameter *display-name*
  "GAW")

(defparameter *source-ref-prefix*
  "refs/heads/")

(defparameter *target-ref-prefix*
  "refs/gaw/heads/")

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

(defun make-ref (source-ref)
  (check-type source-ref
              string)
  (unless (%ref-under-prefix-p source-ref
                               *source-ref-prefix*)
    (error "Not a valid source ref: ~S"
           source-ref))
  (concatenate 'string
               *target-ref-prefix*
               (subseq source-ref
                       (length *source-ref-prefix*))))

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
           (%make-ref-state :name checked-ref
                            :exists-p t
                            :symbolic-p nil))
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

(defun register-ref (source-ref directory &key overwrite)
  (let* ((target-ref (make-ref source-ref))
         (target-state (inspect-ref target-ref
                                    directory)))
    (when (and (not overwrite)
               (ref-state-exists-p target-state))
      (error "~A branch registration already exists: ~S"
             *display-name*
             target-ref))
    (let ((invocation (run-git (list "symbolic-ref"
                                     target-ref
                                     source-ref)
                               directory)))
      (unless (zerop (git-invocation-exit-status invocation))
        (error "Failed to register ~A branch ~S: ~A"
               *display-name*
               source-ref
               (git-invocation-stderr invocation)))
      target-ref)))

(defun unregister-ref (target-ref directory)
  (check-type target-ref
              string)
  (unless (%ref-under-prefix-p target-ref
                               *target-ref-prefix*)
    (error "Not a valid target ref: ~S"
           target-ref))
  (let ((target-state (inspect-ref target-ref
                                   directory)))
    (unless (ref-state-exists-p target-state)
      (error "~A branch registration does not exist: ~S"
             *display-name*
             target-ref))
    (unless (ref-state-symbolic-p target-state)
      (error "~A branch registration is not a symbolic ref: ~S"
             *display-name*
             target-ref))
    (let ((invocation (run-git (list "symbolic-ref"
                                     "--delete"
                                     target-ref)
                               directory)))
      (unless (zerop (git-invocation-exit-status invocation))
        (error "Failed to unregister ~A branch ~S: ~A"
               *display-name*
               target-ref
               (git-invocation-stderr invocation)))
      target-ref)))
