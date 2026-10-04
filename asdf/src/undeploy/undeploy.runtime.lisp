(in-package #:git-agent-workflow.undeploy)

(defun %undeploy-candidates (directory selector source-prefix
                             legacy-prefix protocol-prefix)
  (sort
   (remove-duplicates
    (append (protocol-refs directory)
            (when (and selector
                       (ref-state-exists-p selector)
                       (ref-state-symbolic-p selector)
                       (uiop:string-prefix-p
                        protocol-prefix
                        (ref-state-symbolic-target selector)))
              (list (ref-state-symbolic-target selector)))
            (loop for source in (local-branches directory)
                  collect (concatenate 'string legacy-prefix
                                       (subseq source
                                               (length source-prefix)))))
    :test #'string=)
   #'string<))

(defun %undeploy (directory head-ref source-prefix legacy-prefix
                  protocol-prefix)
  (let ((probe (run-git '("rev-parse" "--git-dir") directory)))
    (unless (zerop (git-invocation-exit-status probe))
      (error "Not a Git repository: ~A" (git-invocation-stderr probe))))
  (let ((selector nil)
        (candidates '())
        (residuals '())
        (removed-selector nil)
        (removed-legacy '())
        (hook-cleared nil))
    (handler-case
        (setf selector (inspect-ref head-ref directory))
      (error (condition)
        (push (format nil "Cannot inspect ~A: ~A" head-ref condition)
              residuals)))
    (handler-case
        (setf candidates
              (%undeploy-candidates directory selector
                                     source-prefix legacy-prefix
                                     protocol-prefix))
      (error (condition)
        (push (format nil "Cannot discover protocol refs: ~A" condition)
              residuals)))
    (when (and selector (ref-state-exists-p selector))
      (handler-case
          (progn (delete-selector directory)
                 (setf removed-selector t))
        (error (condition)
          (push (format nil "Cannot remove ~A: ~A" head-ref condition)
                residuals))))
    (dolist (ref candidates)
      (unless (string= ref head-ref)
        (handler-case
            (let ((state (inspect-ref ref directory)))
              (when (ref-state-exists-p state)
                (let ((expected (%legacy-ref-source
                                 ref legacy-prefix source-prefix)))
                  (if (and expected
                           (ref-state-symbolic-p state)
                           (string= expected
                                    (ref-state-symbolic-target state)))
                      (handler-case
                          (progn
                            (delete-symbolic-ref ref expected directory)
                            (push ref removed-legacy))
                        (error (condition)
                          (push (format nil "Cannot remove ~A: ~A"
                                        ref condition)
                                residuals)))
                      (push (format nil "Preserving unsafe protocol ref ~A"
                                    ref)
                            residuals)))))
          (error (condition)
            (push (format nil "Cannot inspect ~A: ~A" ref condition)
                  residuals)))))
    (handler-case
        (progn (remove-protection-hook directory)
               (setf hook-cleared t))
      (error (condition)
        (push (format nil "Cannot remove GAW hook config: ~A" condition)
              residuals)))
    (%make-undeploy-result removed-selector (nreverse removed-legacy)
                           hook-cleared (nreverse residuals))))
