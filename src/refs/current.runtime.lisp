(in-package #:git-agent-workflow.refs)

(eval-when (:load-toplevel :execute)
  (dolist (function '(inspect-ref
                      %current-registration-ref
                      %current-source-ref
                      %ensure-current-source-exists))
    (unless (fboundp function)
      (error "Required current ref dependency is unavailable: ~S"
             function))))

(defun %current-ref (directory
                     display-name
                     head-ref
                     source-ref-prefix
                     target-ref-prefix)
  (let* ((head-state (inspect-ref head-ref
                                  directory))
         (registration-ref
           (%current-registration-ref head-state
                                      display-name
                                      head-ref
                                      target-ref-prefix))
         (registration-state
           (inspect-ref registration-ref
                        directory))
         (source-ref
           (%current-source-ref registration-state
                                display-name
                                registration-ref
                                source-ref-prefix))
         (source-state (inspect-ref source-ref
                                    directory)))
    (%ensure-current-source-exists source-state
                                   display-name
                                   registration-ref
                                   source-ref)))
