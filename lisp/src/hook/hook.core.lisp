(in-package #:git-agent-workflow.hook)

(define-condition hook-error (error)
  ((reason :initarg :reason
           :reader hook-error-reason)
   (ref :initarg :ref
        :initform nil
        :reader hook-error-ref)
   (detail :initarg :detail
           :initform nil
           :reader hook-error-detail)
   (cause :initarg :cause
          :initform nil
          :reader hook-error-cause))
  (:report (lambda (condition stream)
             (case (hook-error-reason condition)
               (:invalid-phase
                (format stream
                        "Invalid reference-transaction phase: ~A"
                        (hook-error-detail condition)))
               (:invalid-input
                (format stream
                        "Invalid reference-transaction input: ~A"
                        (hook-error-detail condition)))
               (:protected-ref
                (format stream
                        "Refusing to modify valid GAW branch: ~A"
                        (hook-error-ref condition)))
               (:protected-marker
                (format stream
                        "Refusing to change .gaw/config marker on: ~A"
                        (hook-error-ref condition)))
               (:protected-protocol-ref
                (format stream
                        "Refusing to modify GAW protocol ref: ~A"
                        (hook-error-ref condition)))
               (:state-query-failure
                (format stream
                        "Cannot determine GAW branch state for ~A: ~A"
                        (hook-error-ref condition)
                        (hook-error-detail condition)))
               (:runtime-failure
                (format stream
                        "Failed to process reference transaction: ~A"
                        (hook-error-detail condition)))
               (otherwise
                (format stream
                        "Reference-transaction hook failed: ~A"
                        (hook-error-reason condition)))))))

(define-condition hook-configuration-error (error)
  ((reason :initarg :reason
           :reader hook-configuration-error-reason)
   (detail :initarg :detail
           :initform nil
           :reader %hook-configuration-error-detail))
  (:report (lambda (condition stream)
             (format stream "GAW protection hook configuration failed (~S)~@[: ~A~]"
                     (hook-configuration-error-reason condition)
                     (%hook-configuration-error-detail condition)))))

(defstruct (hook-configuration
            (:constructor %make-hook-configuration (status detail))
            (:copier nil))
  (status nil :type (member :absent :canonical :conflict) :read-only t)
  (detail "" :type string :read-only t))

(defun %signal-hook-configuration-error (reason control &rest arguments)
  (error 'hook-configuration-error
         :reason reason
         :detail (when control (apply #'format nil control arguments))))

(defstruct (%reference-update
            (:constructor %make-reference-update))
  old-value
  new-value
  ref)

(defun %signal-hook-error (reason &key ref detail cause)
  (error 'hook-error
         :reason reason
         :ref ref
         :detail detail
         :cause cause))

(defun %reference-transaction-phase (phase)
  (check-type phase string)
  (cond
    ((string= phase "preparing")
     :preparing)
    ((string= phase "prepared")
     :prepared)
    ((string= phase "committed")
     :committed)
    ((string= phase "aborted")
     :aborted)
    (t
     (%signal-hook-error :invalid-phase
                         :detail phase))))

(defun %whitespace-character-p (character)
  (member character
          '(#\Space #\Tab #\Newline #\Return)
          :test #'char=))

(defun %symbolic-transaction-value-p (value)
  (and (> (length value) 4)
       (string= "ref:" value :end2 4)
       (notany #'%whitespace-character-p value)))

(defun %object-transaction-value-p (value)
  (and (plusp (length value))
       (every (lambda (character)
                (digit-char-p character 16))
              value)))

(defun %transaction-value-p (value)
  (or (%object-transaction-value-p value)
      (%symbolic-transaction-value-p value)))

(defun %reference-update-symbolic-p (update)
  (or (%symbolic-transaction-value-p
       (%reference-update-old-value update))
      (%symbolic-transaction-value-p
       (%reference-update-new-value update))))

(defun %parse-reference-transaction-line (line)
  (check-type line string)
  (let* ((first-separator (position #\Space line))
         (second-separator
           (and first-separator
                (position #\Space line
                          :start (1+ first-separator)))))
    (unless (and first-separator
                 second-separator
                 (not (position #\Space line
                                :start (1+ second-separator))))
      (%signal-hook-error :invalid-input
                          :detail "expected three space-separated fields"))
    (let ((old-value (subseq line 0 first-separator))
          (new-value (subseq line
                             (1+ first-separator)
                             second-separator))
          (ref (subseq line (1+ second-separator))))
      (unless (and (%transaction-value-p old-value)
                   (%transaction-value-p new-value)
                   (plusp (length ref))
                   (notany #'%whitespace-character-p ref))
        (%signal-hook-error :invalid-input
                            :detail "invalid old value, new value, or ref name"))
      (%make-reference-update :old-value old-value
                              :new-value new-value
                              :ref ref))))

(defun %ref-under-prefix-p (ref prefix)
  (and (> (length ref)
          (length prefix))
       (string= prefix ref :end2 (length prefix))))
