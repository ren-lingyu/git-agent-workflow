(in-package #:git-agent-workflow.status)

(define-condition status-error (error)
  ((reason :initarg :reason :reader status-error-reason)
   (detail :initarg :detail :reader %status-error-detail))
  (:report (lambda (condition stream)
             (format stream "GAW status failed (~(~A~)): ~A"
                     (status-error-reason condition)
                     (%status-error-detail condition)))))

(defstruct (status-protocol-ref
            (:constructor %make-status-protocol-ref
                (name kind value status detail))
            (:copier nil))
  (name "" :type string :read-only t)
  (kind :missing :type (member :missing :symbolic :direct :unreadable)
        :read-only t)
  (value nil :type (or null string) :read-only t)
  (status :missing :type keyword :read-only t)
  (detail "" :type string :read-only t))

(defstruct (status-branch
            (:constructor %make-status-branch
                (ref object-id classification registration-status
                 committed-state))
            (:copier nil))
  (ref "" :type string :read-only t)
  (object-id nil :type (or null string) :read-only t)
  (classification :ordinary :type (member :ordinary :valid :invalid)
                  :read-only t)
  (registration-status :missing :type keyword :read-only t)
  (committed-state nil :read-only t))

(defstruct (status-report
            (:constructor %make-status-report
                (repository branches protocol-refs selector worktrees hook))
            (:copier nil))
  (repository nil :type pathname :read-only t)
  (branches '() :type list :read-only t)
  (protocol-refs '() :type list :read-only t)
  (selector nil :type status-protocol-ref :read-only t)
  (worktrees '() :type list :read-only t)
  (hook nil :read-only t))

(defun %signal-status-error (reason control &rest arguments)
  (error 'status-error :reason reason
         :detail (apply #'format nil control arguments)))

(defun %status-branch-detail (branch)
  (let* ((report (status-branch-committed-state branch))
         (finding
           (when report
             (find :error (committed-state-report-findings report)
                   :key #'committed-state-finding-status))))
    (cond (finding (committed-state-finding-detail finding))
          ((eq :invalid (status-branch-classification branch))
           "Source ref is missing or symbolic"))))

(defun %status-worktree-description (record)
  (cond
    ((worktree-record-bare-p record) "bare")
    ((worktree-record-detached-p record) "detached")
    ((worktree-record-branch record)
     (worktree-record-branch record))
    (t "no branch")))

(defun status-report-ok-p (report)
  (check-type report status-report)
  (and (notany (lambda (branch)
                 (eq :invalid (status-branch-classification branch)))
               (status-report-branches report))
       (notany (lambda (ref)
                 (member (status-protocol-ref-status ref)
                         '(:invalid :orphan :unreadable)))
               (status-report-protocol-refs report))
       (not (null
             (member (status-protocol-ref-status
                      (status-report-selector report))
                     '(:missing :valid))))
       (not (eq :conflict
                (hook-configuration-status (status-report-hook report))))))

(defun write-status-report (report &optional (stream *standard-output*))
  (check-type report status-report)
  (format stream "GAW repository: ~A~%" (status-report-repository report))
  (let ((selector (status-report-selector report))
        (hook (status-report-hook report)))
    (format stream "Selector: ~(~A~)~@[ -> ~A~]~@[ (~A)~]~%"
            (status-protocol-ref-status selector)
            (status-protocol-ref-value selector)
            (and (not (string= (status-protocol-ref-detail selector) ""))
                 (status-protocol-ref-detail selector)))
    (format stream "Protection hook: ~(~A~) (~A)~%"
            (hook-configuration-status hook)
            (hook-configuration-detail hook)))
  (let ((gaw-branches
          (remove :ordinary (status-report-branches report)
                  :key #'status-branch-classification))
        (ordinary-branches
          (remove-if-not
           (lambda (branch)
             (eq :ordinary (status-branch-classification branch)))
           (status-report-branches report))))
    (format stream "~%GAW branches (~D):~%" (length gaw-branches))
    (dolist (branch gaw-branches)
      (format stream "  ~A ~@[~A ~]~(~A~); registration ~(~A~)~@[; ~A~]~%"
              (status-branch-ref branch)
              (status-branch-object-id branch)
              (status-branch-classification branch)
              (status-branch-registration-status branch)
              (%status-branch-detail branch))
      (dolist (worktree (status-report-worktrees report))
        (when (equal (status-branch-ref branch)
                     (worktree-record-branch worktree))
          (format stream "    at ~A~%" (worktree-record-path worktree)))))
    (format stream "~%Ordinary branches (~D):~%"
            (length ordinary-branches))
    (dolist (branch ordinary-branches)
      (format stream "  ~A~%" (status-branch-ref branch))))
  (let ((refs (remove "refs/gaw/HEAD"
                      (status-report-protocol-refs report)
                      :key #'status-protocol-ref-name :test #'string=)))
    (format stream "~%GAW protocol refs (~D):~%" (length refs))
    (dolist (ref refs)
      (format stream "  ~A ~(~A~)~@[ -> ~A~]~@[ (~A)~]~%"
              (status-protocol-ref-name ref)
              (status-protocol-ref-status ref)
              (status-protocol-ref-value ref)
              (and (not (string= (status-protocol-ref-detail ref) ""))
                   (status-protocol-ref-detail ref)))))
  (format stream "~%Worktrees (~D):~%"
          (length (status-report-worktrees report)))
  (dolist (worktree (status-report-worktrees report))
    (format stream "  ~A: ~A~@[ (prunable)~]~%"
            (worktree-record-path worktree)
            (%status-worktree-description worktree)
            (worktree-record-prunable-p worktree)))
  report)
