(in-package #:git-agent-workflow.undeploy)

(defstruct (undeploy-result
            (:constructor %make-undeploy-result
                (removed-selector-p removed-legacy-refs hook-cleared-p
                 residuals))
            (:copier nil))
  (removed-selector-p nil :type boolean :read-only t)
  (removed-legacy-refs '() :type list :read-only t)
  (hook-cleared-p nil :type boolean :read-only t)
  (residuals '() :type list :read-only t))

(defun undeploy-result-ok-p (result)
  (check-type result undeploy-result)
  (null (undeploy-result-residuals result)))

(defun %legacy-ref-source (ref prefix source-prefix)
  (when (and (> (length ref) (length prefix))
             (string= prefix ref :end2 (length prefix)))
    (concatenate 'string source-prefix
                 (subseq ref (length prefix)))))
