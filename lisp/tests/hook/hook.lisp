(in-package #:git-agent-workflow/tests.hook)

(defun %hook-failure-reason (thunk)
  (handler-case (progn (funcall thunk) nil)
    (hook-error (condition) (hook-error-reason condition))))

(defun %test-parser ()
  (assert (string= "refs/heads/test"
                   (git-agent-workflow.hook::%reference-update-ref
                    (git-agent-workflow.hook::%parse-reference-transaction-line
                     "012abc 789def refs/heads/test"))))
  (assert (string= "refs/heads/test"
                   (git-agent-workflow.hook::%reference-update-ref
                    (git-agent-workflow.hook::%parse-reference-transaction-line
                     "ref:refs/heads/old ref:refs/heads/new refs/heads/test"))))
  (dolist (line '("" "0 1" "0 1 refs/heads/test extra"
                  "not-an-oid 1 refs/heads/test"))
    (assert (eq :invalid-input
                (%hook-failure-reason
                 (lambda ()
                   (git-agent-workflow.hook::%parse-reference-transaction-line
                    line)))))))

(defun %test-phases ()
  (dolist (phase '("prepared" "committed" "aborted"))
    (let ((stream (make-string-input-stream "unread")))
      (assert (reference-transaction phase #p"./" stream))
      (assert (char= #\u (read-char stream)))))
  (assert (eq :invalid-phase
              (%hook-failure-reason
               (lambda () (reference-transaction
                           "future" #p"./" (make-string-input-stream ""))))))
  (assert (eq :runtime-failure
              (%hook-failure-reason
               (lambda () (reference-transaction
                           42 #p"./" (make-string-input-stream "")))))))

(defun %test-actual-tip-overrides-transaction-old-value ()
  (let ((update (git-agent-workflow.hook::%parse-reference-transaction-line
                 "0000 1111 refs/heads/gaw"))
        (state (git-agent-workflow.refs::%make-ref-state
                :name "refs/heads/gaw" :exists-p t :object-id "aaaa")))
    (assert
     (eq :protected-ref
         (%hook-failure-reason
          (lambda ()
            (git-agent-workflow.hook::%protect-source-update
             update "refs/heads/gaw" #p"./"
             (lambda (ref directory) (declare (ignore ref directory)) state)
             (lambda (directory revision)
               (declare (ignore directory revision)) "100644 blob marker")
             (lambda (directory revision)
               (declare (ignore directory revision)) :report)
             (lambda (report) (declare (ignore report)) :valid))))))))

(defun %test-first-marker-appearance-is-allowed ()
  (let ((update (git-agent-workflow.hook::%parse-reference-transaction-line
                 "0000 1111 refs/heads/new"))
        (state (git-agent-workflow.refs::%make-ref-state
                :name "refs/heads/new" :exists-p t :object-id "aaaa")))
    (assert
     (null (git-agent-workflow.hook::%protect-source-update
      update "refs/heads/new" #p"./"
      (lambda (ref directory) (declare (ignore ref directory)) state)
      (lambda (directory revision)
        (declare (ignore directory revision)) nil)
      (lambda (directory revision)
        (declare (ignore directory revision))
        (error "No committed-state validation is needed"))
      (lambda (report) (declare (ignore report))
        (error "No classification is needed")))))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.hook)))
    (dolist (name '("REFERENCE-TRANSACTION" "HOOK-ERROR"
                    "HOOK-ERROR-REASON"))
      (multiple-value-bind (symbol status) (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun %run-hook-tests ()
  (%test-parser)
  (%test-phases)
  (%test-actual-tip-overrides-transaction-old-value)
  (%test-first-marker-appearance-is-allowed)
  (%test-public-package-boundary)
  (format t "~&All hook tests passed.~%")
  t)
