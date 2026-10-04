(in-package #:git-agent-workflow/tests.status)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %branch (report ref)
  (find ref (status-report-branches report) :test #'string=
        :key #'status-branch-ref))

(defun %protocol (report ref)
  (find ref (status-report-protocol-refs report) :test #'string=
        :key #'status-protocol-ref-name))

(defun %test-content-identity-and-selector ()
  (with-test-repository (directory)
    (assert (status-report-ok-p (status directory)))
    (initialize directory :branch "gaw")
    (let ((report (status directory)))
      (assert (status-report-ok-p report))
      (assert (eq :valid (status-branch-classification
                          (%branch report "refs/heads/gaw"))))
      (assert (eq :valid (status-protocol-ref-status
                          (status-report-selector report)))))
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "--delete" "refs/gaw/HEAD")
    (let ((report (status directory)))
      (assert (status-report-ok-p report))
      (assert (eq :missing (status-protocol-ref-status
                            (status-report-selector report))))
      (assert (eq :valid (status-branch-classification
                          (%branch report "refs/heads/gaw")))))))

(defun %test-invalid-selector-and-unexpected-refs ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/HEAD" "refs/heads/missing")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/heads/legacy" "refs/heads/gaw")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/extra" "refs/heads/gaw")
    (let ((report (status directory)))
      (assert (not (status-report-ok-p report)))
      (assert (eq :invalid (status-protocol-ref-status
                            (status-report-selector report))))
      (assert (eq :unknown (status-protocol-ref-status
                            (%protocol report "refs/gaw/heads/legacy"))))
      (assert (eq :unknown (status-protocol-ref-status
                            (%protocol report "refs/gaw/extra")))))))

(defun %test-invalid-marker-and-ordinary-branch ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let* ((tree (%git directory "mktree"))
           (ordinary (%git directory "-c" "user.name=GAW Test"
                           "-c" "user.email=gaw-test@example.invalid"
                           "commit-tree" tree "-m" "ordinary")))
      (%git directory "update-ref" "refs/heads/ordinary" ordinary))
    (write-test-octets (merge-pathnames ".gaw/config" directory)
                       #(40 58 119 111 114 107 115 112 97 99 101))
    (%git directory "add" "--" ".gaw/config")
    (let* ((tree (%git directory "write-tree"))
           (invalid (%git directory "-c" "user.name=GAW Test"
                          "-c" "user.email=gaw-test@example.invalid"
                          "commit-tree" tree "-m" "bad config")))
      (%git directory "update-ref" "refs/heads/invalid" invalid))
    (let ((report (status directory)))
      (assert (eq :ordinary (status-branch-classification
                             (%branch report "refs/heads/ordinary"))))
      (assert (eq :invalid (status-branch-classification
                            (%branch report "refs/heads/invalid"))))
      (assert (not (status-report-ok-p report))))))

(defun %test-bare-and-reftable ()
  (dolist (backend '("files" "reftable"))
    (with-temporary-directory (directory)
      (call-git (list "init" "--bare" "--quiet"
                      (format nil "--ref-format=~A" backend)
                      (namestring directory)))
      (assert (status-report-ok-p (status directory)))
      (initialize directory :branch "gaw")
      (assert (status-report-ok-p (status directory))))))

(defun %test-diagnostic-arguments-and-result ()
  (with-test-repository (directory)
    (let* ((symbol 'git-agent-workflow.git:run-git-passthrough)
           (original (symbol-function symbol))
           (seen nil))
      (unwind-protect
           (progn
             (setf (symbol-function symbol)
                   (lambda (arguments git-directory &key git-environment)
                     (declare (ignore git-environment))
                     (setf seen (list arguments git-directory))
                     (git-agent-workflow.git::%make-git-invocation
                      :exit-status 7)))
             (assert (= 7 (diagnose-status directory)))
             (assert (equal '("fsck" "--connectivity-only" "--no-reflogs"
                              "--no-dangling" "--no-progress")
                            (first seen)))
             (assert (equal directory (second seen))))
        (setf (symbol-function symbol) original)))))

(defun run-tests ()
  (%test-content-identity-and-selector)
  (%test-invalid-selector-and-unexpected-refs)
  (%test-invalid-marker-and-ordinary-branch)
  (%test-bare-and-reftable)
  (%test-diagnostic-arguments-and-result)
  (format t "~&All status tests passed.~%")
  t)
