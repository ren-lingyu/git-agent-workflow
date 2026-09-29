(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(run-git
                      git-invocation-stdout
                      git-invocation-stderr
                      git-invocation-exit-status
                      %make-ref-state
                      %make-ref
                      %ref-state-dangling-p
                      %ensure-registration-available
                      %validate-target-ref
                      %ensure-registration-removable))
    (unless (fboundp function)
      (error "Required runtime dependency is unavailable: ~S"
             function))))

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
         (%ref-state-dangling-p
          ref-state
          (inspect-ref (ref-state-symbolic-target ref-state)
                       directory)))))

(defun %register-ref (source-ref
                      directory
                      overwrite
                      display-name
                      source-ref-prefix
                      target-ref-prefix)
  (let* ((target-ref (%make-ref source-ref
                                source-ref-prefix
                                target-ref-prefix))
         (target-state (inspect-ref target-ref
                                    directory)))
    (%ensure-registration-available target-state
                                    overwrite
                                    display-name
                                    target-ref)
    (let ((invocation (run-git (list "symbolic-ref"
                                     target-ref
                                     source-ref)
                               directory)))
      (unless (zerop (git-invocation-exit-status invocation))
        (error "Failed to register ~A branch ~S: ~A"
               display-name
               source-ref
               (git-invocation-stderr invocation)))
      target-ref)))

(defun %unregister-ref (target-ref
                        directory
                        display-name
                        target-ref-prefix)
  (%validate-target-ref target-ref
                        target-ref-prefix)
  (let ((target-state (inspect-ref target-ref
                                   directory)))
    (%ensure-registration-removable target-state
                                    display-name
                                    target-ref)
    (let ((invocation (run-git (list "symbolic-ref"
                                     "--delete"
                                     target-ref)
                               directory)))
      (unless (zerop (git-invocation-exit-status invocation))
        (error "Failed to unregister ~A branch ~S: ~A"
               display-name
               target-ref
               (git-invocation-stderr invocation)))
      target-ref)))
