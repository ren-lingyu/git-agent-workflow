(in-package #:git-agent-workflow/tests.hook)

(defun %hook-failure-reason (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (hook-error (condition)
      (hook-error-reason condition))))

(defun %transaction-input (&rest refs)
  (with-output-to-string (stream)
    (dolist (ref refs)
      (format stream "0 1 ~A~%" ref))))

(defun %call-runtime (phase input registration-query)
  (git-agent-workflow.hook::%reference-transaction
   phase
   #p"./"
   (make-string-input-stream input)
   (lambda (update directory)
     (declare (ignore directory))
     (let ((transaction-ref
             (git-agent-workflow.hook::%reference-update-ref update)))
       (cond
         ((git-agent-workflow.hook::%ref-under-prefix-p
           transaction-ref
           "refs/heads/")
          transaction-ref)
         ((git-agent-workflow.hook::%reference-update-symbolic-p update)
          nil)
         ((string= transaction-ref "HEAD")
          "refs/heads/current")
         (t
          nil))))
   registration-query
   "refs/gaw/"))

(defun %test-parser-accepts-object-values ()
  (assert
   (string= "refs/heads/test"
            (git-agent-workflow.hook::%reference-update-ref
             (git-agent-workflow.hook::%parse-reference-transaction-line
              "012abc 789def refs/heads/test")))))

(defun %test-parser-accepts-symbolic-values ()
  (assert
   (string= "refs/heads/test"
            (git-agent-workflow.hook::%reference-update-ref
             (git-agent-workflow.hook::%parse-reference-transaction-line
              "ref:refs/heads/old ref:refs/heads/new refs/heads/test")))))

(defun %test-parser-rejects-malformed-input ()
  (dolist (line (list ""
                      "0 1"
                      "0 1 refs/heads/test extra"
                      "not-an-oid 1 refs/heads/test"
                      (format nil
                              "0 1 refs/heads/test~Cbad"
                              #\Tab)))
    (assert
     (eq :invalid-input
         (%hook-failure-reason
          (lambda ()
            (git-agent-workflow.hook::%parse-reference-transaction-line
             line)))))))

(defun %test-preparing-rejects-registered-ref ()
  (assert
   (eq :protected-ref
       (%hook-failure-reason
        (lambda ()
          (%call-runtime
           "preparing"
           (%transaction-input "refs/heads/test")
           (lambda (ref directory)
             (declare (ignore ref directory))
             t)))))))

(defun %test-preparing-allows-unregistered-ref ()
  (assert
   (%call-runtime
    "preparing"
    (%transaction-input "refs/heads/test")
    (lambda (ref directory)
      (declare (ignore ref directory))
      nil))))

(defun %test-preparing-rejects-protocol-refs ()
  (let ((queries 0))
    (assert
     (eq :protected-protocol-ref
         (%hook-failure-reason
          (lambda ()
            (%call-runtime
             "preparing"
             (%transaction-input "refs/gaw/heads/test")
             (lambda (ref directory)
               (declare (ignore ref directory))
               (incf queries)
               t))))))
    (assert (zerop queries))))

(defun %test-preparing-ignores-other-namespaces ()
  (assert
   (%call-runtime
    "preparing"
    (%transaction-input "refs/tags/test")
    (lambda (ref directory)
      (declare (ignore ref directory))
      (error "registration query must not run")))))

(defun %test-preparing-deduplicates-refs ()
  (let ((queries 0))
    (assert
     (%call-runtime
      "preparing"
      (%transaction-input "refs/heads/test" "refs/heads/test")
      (lambda (ref directory)
        (declare (ignore ref directory))
        (incf queries)
        nil)))
    (assert (= 1 queries))))

(defun %test-preparing-resolves-head-to-current-branch ()
  (let ((seen nil))
    (assert
     (%call-runtime
      "preparing"
      (%transaction-input "HEAD")
      (lambda (ref directory)
        (declare (ignore directory))
        (setf seen ref)
        nil)))
    (assert (string= "refs/heads/current" seen))))

(defun %test-preparing-ignores-symbolic-head-update ()
  (let ((queries 0))
    (assert
     (%call-runtime
      "preparing"
      (format nil
              "ref:refs/heads/current ref:refs/heads/other HEAD~%")
      (lambda (ref directory)
        (declare (ignore ref directory))
        (incf queries)
        t)))
    (assert (zerop queries))))

(defun %test-preparing-rejects-mixed-transaction ()
  (assert
   (eq :protected-ref
       (%hook-failure-reason
        (lambda ()
          (%call-runtime
           "preparing"
           (%transaction-input "refs/heads/free" "refs/heads/protected")
           (lambda (ref directory)
             (declare (ignore directory))
             (string= ref "refs/heads/protected"))))))))

(defun %test-registration-errors-are-wrapped ()
  (assert
   (eq :invalid-registration
       (%hook-failure-reason
        (lambda ()
          (%call-runtime
           "preparing"
           (%transaction-input "refs/heads/test")
           (lambda (ref directory)
             (declare (ignore directory))
             (error 'registration-error
                    :reason :direct-registration
                    :ref ref))))))))

(defun %test-query-errors-are-wrapped ()
  (assert
   (eq :registration-query-failure
       (%hook-failure-reason
        (lambda ()
          (%call-runtime
           "preparing"
           (%transaction-input "refs/heads/test")
           (lambda (ref directory)
             (declare (ignore ref directory))
             (error "query failed"))))))))

(defun %test-non-preparing-phases-do-not-read-input ()
  (dolist (phase '("prepared" "committed" "aborted"))
    (let ((stream (make-string-input-stream "unread")))
      (assert (reference-transaction phase #p"./" stream))
      (assert (char= #\u (read-char stream))))))

(defun %test-unknown-phase-is-rejected ()
  (assert
   (eq :invalid-phase
       (%hook-failure-reason
        (lambda ()
          (reference-transaction "future" #p"./"
                                 (make-string-input-stream "")))))))

(defun %test-unexpected-api-error-is-wrapped ()
  (assert
   (eq :runtime-failure
       (%hook-failure-reason
        (lambda ()
          (reference-transaction 42 #p"./"
                                 (make-string-input-stream "")))))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.hook)))
    (dolist (name '("REFERENCE-TRANSACTION"
                    "HOOK-ERROR"
                    "HOOK-ERROR-REASON"))
      (multiple-value-bind (symbol status)
          (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun %run-hook-tests ()
  (%test-parser-accepts-object-values)
  (%test-parser-accepts-symbolic-values)
  (%test-parser-rejects-malformed-input)
  (%test-preparing-rejects-registered-ref)
  (%test-preparing-allows-unregistered-ref)
  (%test-preparing-rejects-protocol-refs)
  (%test-preparing-ignores-other-namespaces)
  (%test-preparing-deduplicates-refs)
  (%test-preparing-resolves-head-to-current-branch)
  (%test-preparing-ignores-symbolic-head-update)
  (%test-preparing-rejects-mixed-transaction)
  (%test-registration-errors-are-wrapped)
  (%test-query-errors-are-wrapped)
  (%test-non-preparing-phases-do-not-read-input)
  (%test-unknown-phase-is-rejected)
  (%test-unexpected-api-error-is-wrapped)
  (%test-public-package-boundary)
  (format t "~&All hook tests passed.~%")
  t)
