(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(inspect-ref %current-source-target))
    (unless (fboundp function)
      (error "Required current ref dependency is unavailable: ~S" function))))

(defun %current-ref (directory display-name head-ref source-prefix)
  (let* ((head (inspect-ref head-ref directory))
         (source-ref (%current-source-target head display-name head-ref
                                             source-prefix))
         (source (inspect-ref source-ref directory)))
    (unless (and (ref-state-exists-p source)
                 (not (ref-state-symbolic-p source)))
      (error 'current-ref-error :display-name display-name
             :reason :missing-source :ref source-ref :target source-ref))
    source-ref))
