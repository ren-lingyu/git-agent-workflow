(in-package #:git-agent-workflow/tests.cli)

(defun %test-message-fragments-follow-commit-tree-semantics ()
  (with-temporary-directory (directory)
    (let ((file (merge-pathnames "message"
                                 directory)))
      (write-test-octets file
                         (make-array 2
                                     :element-type '(unsigned-byte 8)
                                     :initial-contents '(66 0)))
      (assert
       (equalp
        (make-array 8
                    :element-type '(unsigned-byte 8)
                    :initial-contents '(65 10 10 66 0 10 67 10))
        (git-agent-workflow.cli::%message-from-fragments
         (list (cons :message "A")
               (cons :file (namestring file))
               (cons :message "C"))))))))

(defun %test-commit-argument-parser ()
  (multiple-value-bind (message parents allow-empty allow-empty-message)
      (git-agent-workflow.cli::%parse-commit-arguments
       '("-mone" "--allow-empty" "parent" "--" "-parent"))
    (assert (equalp #(111 110 101 10)
                    message))
    (assert (equal '("parent" "-parent")
                   parents))
    (assert allow-empty)
    (assert (not allow-empty-message))))

(defun %dispatch-output (arguments directory)
  (let ((status nil))
    (values
     (with-output-to-string (stream)
       (setf status
             (git-agent-workflow.cli::%dispatch arguments directory stream)))
     status)))

(defun %test-help-dispatch ()
  (with-temporary-directory (directory)
    (multiple-value-bind (overview status)
        (%dispatch-output '("help") directory)
      (assert (zerop status))
      (assert (string= overview
                       (nth-value 0 (%dispatch-output '("--help") directory))))
      (assert (string= overview
                       (nth-value 0 (%dispatch-output '("-h") directory)))))
    (dolist (command '("commit" "show" "check" "status" "deploy"
                       "undeploy" "init" "branch"))
      (let ((topic (nth-value 0
                             (%dispatch-output (list "help" command)
                                               directory)))
            (option (nth-value 0
                              (%dispatch-output (list command "--help")
                                                directory))))
        (assert (string= topic option))))
    (dolist (topic '("hooks" "recovery"))
      (assert (plusp (length (nth-value 0
                             (%dispatch-output (list "help" topic)
                                               directory))))))
    (assert (handler-case
                (progn
                  (%dispatch-output '("help" "config") directory)
                  nil)
              (error () t)))))

(defun %test-deploy-argument-parser ()
  (multiple-value-bind (branch path)
      (git-agent-workflow.cli::%parse-deploy-arguments
       '("--branch=gaw" "--worktree-path" "agent"))
    (assert (string= "gaw" branch))
    (assert (string= "agent" path)))
  (dolist (arguments '(("positional")
                       ("--branch")
                       ("--branch" "one" "--branch" "two")))
    (assert (handler-case
                (progn
                  (git-agent-workflow.cli::%parse-deploy-arguments arguments)
                  nil)
              (error () t)))))

(defun %test-show-help-interception-is-exact ()
  (with-temporary-directory (directory)
    (let* ((symbol 'git-agent-workflow.show:show)
           (original (symbol-function symbol))
           (seen nil))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (show-directory arguments)
                     (assert (equal directory show-directory))
                     (setf seen arguments)
                     23))
             (dolist (arguments '(("show" "--" "--help")
                                  ("show" "HEAD" "--help")))
               (setf seen nil)
               (multiple-value-bind (output status)
                   (%dispatch-output arguments directory)
                 (assert (string= "" output))
                 (assert (= 23 status))
                 (assert (equal (rest arguments) seen)))))
        (setf (symbol-function symbol) original)))))

(defun %test-check-dispatch ()
  (with-temporary-directory (directory)
    (multiple-value-bind (output status)
        (%dispatch-output '("check") directory)
      (assert (= status 1))
      (assert (search "GAW worktree is not ready" output)))))

(defun %test-status-dispatch ()
  (with-test-repository (directory)
    (multiple-value-bind (output status)
        (%dispatch-output '("status") directory)
      (assert (zerop status))
      (assert (search "GAW repository:" output))
      (assert (search "GAW branches (0):" output)))
    (assert (zerop (nth-value 1
                    (%dispatch-output '("status" "--diagnose") directory))))
    (assert (handler-case
                (progn (%dispatch-output '("status" "extra") directory)
                       nil)
              (error () t)))
    (assert (handler-case
                (progn (%dispatch-output '("status" "--diagnose" "extra")
                                         directory)
                       nil)
              (error () t)))))

(defun %test-undeploy-dispatch ()
  (with-test-repository (directory)
    (git-agent-workflow.init:initialize directory :branch "gaw")
    (multiple-value-bind (output status)
        (%dispatch-output '("undeploy") directory)
      (assert (zerop status))
      (assert (search "GAW selector: removed" output)))
    (assert (zerop (nth-value 1
                    (%dispatch-output '("undeploy") directory))))
    (assert (handler-case
                (progn (%dispatch-output '("undeploy" "extra") directory)
                       nil)
              (error () t)))))

(defun %test-status-diagnostic-exit-combination ()
  (with-test-repository (directory)
    (let* ((diagnose-symbol 'git-agent-workflow.status:diagnose-status)
           (writer-symbol 'git-agent-workflow.status:write-status-report)
           (original-diagnose (symbol-function diagnose-symbol))
           (original-writer (symbol-function writer-symbol))
           (diagnostic-status 0)
           (diagnostic-calls 0)
           (reported nil))
      (unwind-protect
           (progn
             (setf (symbol-function writer-symbol)
                   (lambda (report &optional (stream *standard-output*))
                     (prog1 (funcall original-writer report stream)
                       (setf reported t))))
             (setf (symbol-function diagnose-symbol)
                   (lambda (git-directory)
                     (assert (equal directory git-directory))
                     (assert reported)
                     (incf diagnostic-calls)
                     diagnostic-status))
             (assert (zerop (nth-value 1
                             (%dispatch-output '("status") directory))))
             (assert (zerop diagnostic-calls))
             (setf reported nil)
             (assert (zerop (nth-value 1
                             (%dispatch-output '("status" "--diagnose")
                                               directory))))
             (assert (= 1 diagnostic-calls))
             (setf diagnostic-status 7 reported nil)
             (assert (= 7 (nth-value 1
                           (%dispatch-output '("status" "--diagnose")
                                             directory))))
             (call-git (list "-C" (namestring directory)
                             "symbolic-ref" "refs/gaw/HEAD"
                             "refs/heads/missing"))
             (setf diagnostic-status 0 reported nil)
             (assert (zerop (nth-value 1
                             (%dispatch-output '("status") directory))))
             (assert (= 1 (nth-value 1
                           (%dispatch-output '("status" "--diagnose")
                                             directory))))
             (setf diagnostic-status 7 reported nil)
             (assert (= 7 (nth-value 1
                           (%dispatch-output '("status" "--diagnose")
                                             directory))))
             (with-temporary-directory (outside)
               (setf reported nil)
               (let ((before diagnostic-calls))
                 (assert (handler-case
                             (progn
                               (%dispatch-output '("status" "--diagnose")
                                                 outside)
                               nil)
                           (error () t)))
                 (assert (= before diagnostic-calls)))))
        (setf (symbol-function diagnose-symbol) original-diagnose
              (symbol-function writer-symbol) original-writer)))))

(defun %test-version-dispatch ()
  (with-temporary-directory (directory)
    (let ((expected
            (format nil
                    "git-gaw ~A~%"
                    (asdf:component-version
                     (asdf:find-system "git-agent-workflow")))))
      (dolist (arguments '(("--version")
                           ("version")))
        (multiple-value-bind (output status)
            (%dispatch-output arguments directory)
          (assert (zerop status))
          (assert (string= expected output))))
      (dolist (arguments '(("--version" "extra")
                           ("version" "extra")))
        (assert
         (handler-case
             (progn
               (%dispatch-output arguments directory)
               nil)
           (error () t)))))))

(defun %test-reference-transaction-machine-option ()
  (with-temporary-directory (directory)
    (let* ((symbol 'git-agent-workflow.hook:reference-transaction)
           (original (symbol-function symbol))
           (seen nil))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (phase hook-directory input-stream)
                     (setf seen
                           (list phase
                                 hook-directory
                                 (read-line input-stream nil nil)))
                     t))
             (let ((*standard-input*
                     (make-string-input-stream "transaction input")))
               (assert
                (zerop
                 (git-agent-workflow.cli::%dispatch
                  '("--reference-transaction" "preparing")
                  directory
                  (make-broadcast-stream)))))
             (assert (equal (list "preparing"
                                  directory
                                  "transaction input")
                            seen)))
        (setf (symbol-function symbol) original)))))

(defun %test-reference-transaction-machine-option-reports-hook-error ()
  (with-temporary-directory (directory)
    (let ((*standard-input* (make-string-input-stream ""))
          (*error-output* (make-string-output-stream)))
      (assert
       (= 1
          (git-agent-workflow.cli::%dispatch
           '("--reference-transaction" "unknown")
           directory
           (make-broadcast-stream))))
      (assert (search "Invalid reference-transaction phase"
                      (get-output-stream-string *error-output*))))))

(defun %test-reference-transaction-machine-option-requires-phase ()
  (with-temporary-directory (directory)
    (assert
     (handler-case
         (progn
           (git-agent-workflow.cli::%dispatch
            '("--reference-transaction")
            directory
            (make-broadcast-stream))
           nil)
       (error () t)))))

(defun %test-main-status-preserves-dispatch-failure ()
  (let ((symbol 'git-agent-workflow.cli::%dispatch)
        (original nil))
    (setf original (symbol-function symbol))
    (unwind-protect
         (progn
           (setf (symbol-function symbol)
                 (lambda (arguments directory output-stream)
                   (declare (ignore arguments directory output-stream))
                   23))
           (assert (= 23
                      (git-agent-workflow.cli::%main-status))))
      (setf (symbol-function symbol) original))))

(defun %run-cli-tests ()
  (%test-message-fragments-follow-commit-tree-semantics)
  (%test-commit-argument-parser)
  (%test-help-dispatch)
  (%test-deploy-argument-parser)
  (%test-show-help-interception-is-exact)
  (%test-check-dispatch)
  (%test-status-dispatch)
  (%test-undeploy-dispatch)
  (%test-status-diagnostic-exit-combination)
  (%test-version-dispatch)
  (%test-reference-transaction-machine-option)
  (%test-reference-transaction-machine-option-reports-hook-error)
  (%test-reference-transaction-machine-option-requires-phase)
  (%test-main-status-preserves-dispatch-failure)
  (format t
          "~&All CLI tests passed.~%")
  t)
