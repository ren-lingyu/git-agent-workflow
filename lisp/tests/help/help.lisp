(in-package #:git-agent-workflow/tests.help)

(defun %render (topic)
  (with-output-to-string (stream)
    (print-help topic stream)))

(defun %test-help-topics ()
  (dolist (topic '(:overview :commit :show :check :deploy :init :branch))
    (let ((text (%render topic)))
      (assert (plusp (length text)))
      (assert (char= #\Newline (char text (1- (length text)))))))
  (assert (search "git gaw check" (%render :check)))
  (assert (search "git gaw deploy" (%render :deploy)))
  (assert (search "git gaw init" (%render :init)))
  (assert (search "git gaw branch" (%render :branch)))
  (assert (search "git gaw --version" (%render :overview)))
  (assert (handler-case
              (progn (print-help :unknown) nil)
            (help-error () t))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.help)))
    (dolist (name '("PRINT-HELP" "HELP-ERROR" "HELP-ERROR-REASON"
                    "HELP-ERROR-TOPIC"))
      (multiple-value-bind (symbol status) (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun run-tests ()
  (%test-help-topics)
  (%test-public-package-boundary)
  (format t "~&All help tests passed.~%")
  t)
