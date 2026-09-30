(in-package #:git-agent-workflow.hook)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%reference-transaction-phase
                      %parse-reference-transaction-line
                      %signal-hook-error))
    (unless (fboundp function)
      (error "Required hook runtime dependency is unavailable: ~S"
             function))))

(defun %registered-ref-p-for-hook (ref directory registration-query)
  (handler-case
      (funcall registration-query ref directory)
    (registration-error (condition)
      (%signal-hook-error :invalid-registration
                          :ref ref
                          :detail (princ-to-string condition)
                          :cause condition))
    (error (condition)
      (%signal-hook-error :registration-query-failure
                          :ref ref
                          :detail (princ-to-string condition)
                          :cause condition))))

(defun %source-ref-for-hook (update
                             directory
                             source-ref-resolver)
  (handler-case
      (funcall source-ref-resolver update directory)
    (error (condition)
      (%signal-hook-error :registration-query-failure
                          :ref (%reference-update-ref update)
                          :detail (princ-to-string condition)
                          :cause condition))))

(defun %preparing-reference-transaction (directory
                                         input-stream
                                         source-ref-resolver
                                         registration-query)
  (let ((seen (make-hash-table :test #'equal))
        (refs '()))
    (loop for line = (read-line input-stream nil nil)
          while line
          for update = (%parse-reference-transaction-line line)
          for source-ref = (%source-ref-for-hook update
                                                  directory
                                                  source-ref-resolver)
          when (and source-ref
                    (not (gethash source-ref seen)))
            do (setf (gethash source-ref seen) t)
               (push source-ref refs))
    (dolist (ref (nreverse refs))
      (when (%registered-ref-p-for-hook ref
                                          directory
                                          registration-query)
        (%signal-hook-error :protected-ref
                            :ref ref)))
    t))

(defun %reference-transaction (phase
                               directory
                               input-stream
                               source-ref-resolver
                               registration-query)
  (case (%reference-transaction-phase phase)
    (:preparing
     (%preparing-reference-transaction directory
                                       input-stream
                                       source-ref-resolver
                                       registration-query))
    ((:prepared :committed :aborted)
     t)))
