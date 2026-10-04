(in-package #:git-agent-workflow.state)

(defstruct (committed-state-finding
            (:constructor %make-committed-state-finding
                (name status detail &optional (certainty :determinate)))
            (:copier nil))
  (name nil :type keyword :read-only t)
  (status nil :type (member :ok :error :skipped) :read-only t)
  (detail "" :type string :read-only t)
  (certainty :determinate :type (member :determinate :indeterminate)
             :read-only t))

(defstruct (committed-state-report
            (:constructor %make-committed-state-report
                (source-ref commit-oid tree-oid config workspace findings))
            (:copier nil))
  (source-ref "" :type string :read-only t)
  (commit-oid nil :type (or null string) :read-only t)
  (tree-oid nil :type (or null string) :read-only t)
  (config nil :read-only t)
  (workspace nil :type list :read-only t)
  (findings '() :type list :read-only t))

(defun committed-state-report-ok-p (report)
  (check-type report committed-state-report)
  (not (find :error
             (committed-state-report-findings report)
             :key #'committed-state-finding-status)))

(defun committed-state-classification (report)
  (check-type report committed-state-report)
  (cond ((committed-state-report-ok-p report) :valid)
        ((find :indeterminate (committed-state-report-findings report)
               :key #'committed-state-finding-certainty)
         :indeterminate)
        (t :invalid)))

(defun committed-state-finding (report name)
  (check-type report committed-state-report)
  (find name
        (committed-state-report-findings report)
        :key #'committed-state-finding-name))
