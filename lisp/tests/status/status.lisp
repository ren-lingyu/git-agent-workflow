(in-package #:git-agent-workflow/tests.status)

(defun %status-git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %status-branch (report ref)
  (find ref (status-report-branches report)
        :test #'string= :key #'status-branch-ref))

(defun %test-ordinary-repository ()
  (with-test-repository (directory)
    (let* ((report (status directory))
           (text (with-output-to-string (stream)
                   (write-status-report report stream))))
      (assert (eq :missing
                  (status-protocol-ref-status
                   (status-report-selector report))))
      (assert (null (status-report-branches report)))
      (assert (status-report-ok-p report))
      (assert (search "GAW branches (0)" text))
      (assert (= 1 (length (status-report-worktrees report)))))))

(defun %test-initialized-repository-and-nested-cwd ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let* ((nested (merge-pathnames "nested/" directory))
           (report (status directory))
           (branch (%status-branch report "refs/heads/gaw")))
      (ensure-directories-exist (merge-pathnames "placeholder" nested))
      (assert (eq :valid (status-branch-classification branch)))
      (assert (status-report-ok-p report))
      (assert (eq :valid
                  (status-protocol-ref-status
                   (status-report-selector report))))
      (assert (string= (with-output-to-string (stream)
                         (write-status-report report stream))
                       (with-output-to-string (stream)
                         (write-status-report (status nested) stream)))))))

(defun %test-protocol-anomalies ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/heads/stray" "refs/heads/gaw")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/heads/dangling" "refs/heads/dangling")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/other" "refs/heads/gaw")
    (let* ((report (status directory))
           (refs (status-report-protocol-refs report))
           (stray (find "refs/gaw/heads/stray" refs :test #'string=
                        :key #'status-protocol-ref-name))
           (dangling (find "refs/gaw/heads/dangling" refs :test #'string=
                           :key #'status-protocol-ref-name))
           (other (find "refs/gaw/other" refs :test #'string=
                        :key #'status-protocol-ref-name)))
      (assert (eq :invalid (status-protocol-ref-status stray)))
      (assert (null dangling))
      (assert (eq :unknown (status-protocol-ref-status other)))
      (assert (not (status-report-ok-p report)))
      (assert (eq :valid
                  (status-protocol-ref-status
                   (status-report-selector report)))))))

(defun %test-selector-discovers-hidden-registration ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/heads/hidden" "refs/heads/hidden")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/HEAD" "refs/gaw/heads/hidden")
    (let* ((report (status directory))
           (registration
             (find "refs/gaw/heads/hidden"
                   (status-report-protocol-refs report)
                   :test #'string= :key #'status-protocol-ref-name)))
      (assert (eq :orphan (status-protocol-ref-status registration)))
      (assert (eq :invalid
                  (status-protocol-ref-status
                   (status-report-selector report))))
      (assert (not (status-report-ok-p report))))))

(defun %test-ordinary-and-invalid-marker-branches ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let* ((empty-tree (%status-git directory "write-tree"))
           (ordinary
             (%status-git directory
                          "-c" "user.name=GAW Test"
                          "-c" "user.email=gaw-test@example.invalid"
                          "commit-tree" empty-tree "-m" "ordinary")))
      (%status-git directory "update-ref" "refs/heads/ordinary" ordinary))
    (write-test-octets (merge-pathnames ".gaw/config" directory)
                       #(40 58 119 111 114 107 115 112 97 99 101))
    (%status-git directory "add" "--" ".gaw/config")
    (let* ((tree (%status-git directory "write-tree"))
           (invalid
             (%status-git directory
                          "-c" "user.name=GAW Test"
                          "-c" "user.email=gaw-test@example.invalid"
                          "commit-tree" tree "-m" "bad config")))
      (%status-git directory "update-ref" "refs/heads/invalid" invalid))
    (let ((report (status directory)))
      (assert (eq :ordinary
                  (status-branch-classification
                   (%status-branch report "refs/heads/ordinary"))))
      (assert (eq :invalid
                  (status-branch-classification
                   (%status-branch report "refs/heads/invalid"))))
      (assert (not (status-report-ok-p report))))))

(defun %test-existing-branch-discovers-hidden-registration ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let* ((tree (%status-git directory "write-tree"))
           (ordinary
             (%status-git directory
                          "-c" "user.name=GAW Test"
                          "-c" "user.email=gaw-test@example.invalid"
                          "commit-tree" tree "-m" "ordinary")))
      (%status-git directory "update-ref" "refs/heads/ordinary" ordinary))
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/heads/ordinary"
                 "refs/heads/missing")
    (let* ((report (status directory))
           (registration
             (find "refs/gaw/heads/ordinary"
                   (status-report-protocol-refs report)
                   :test #'string= :key #'status-protocol-ref-name)))
      (assert (eq :invalid (status-protocol-ref-status registration)))
      (assert (eq :invalid
                  (status-branch-classification
                   (%status-branch report "refs/heads/ordinary"))))
      (assert (not (status-report-ok-p report))))))

(defun %test-unknown-ref-is-informational ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/other" "refs/heads/gaw")
    (let ((report (status directory)))
      (assert (status-report-ok-p report))
      (assert (eq :unknown
                  (status-protocol-ref-status
                   (find "refs/gaw/other"
                         (status-report-protocol-refs report)
                         :test #'string= :key #'status-protocol-ref-name)))))))

(defun %test-hook-conflict-is-protocol-error ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%status-git directory "config" "--local"
                 "hook.gaw-reference-transaction.enabled" "false")
    (assert (not (status-report-ok-p (status directory))))))

(defun %test-bare-repository ()
  (with-temporary-directory (directory)
    (call-git (list "init" "--bare" "--quiet" (namestring directory)))
    (let ((report (status directory)))
      (assert (null (status-report-branches report)))
      (assert (= 1 (length (status-report-worktrees report)))))))

(defun %test-reftable-report ()
  (with-temporary-directory (directory)
    (call-git (list "init" "--bare" "--quiet" "--ref-format=reftable"
                    (namestring directory)))
    (assert (status-report-ok-p (status directory)))
    (initialize directory :branch "gaw")
    (assert (status-report-ok-p (status directory)))
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/heads/hidden" "refs/heads/hidden")
    (%status-git directory "-c" "hook.gaw-reference-transaction.enabled=false"
                 "symbolic-ref" "refs/gaw/HEAD" "refs/gaw/heads/hidden")
    (let* ((report (status directory))
           (registration
             (find "refs/gaw/heads/hidden"
                   (status-report-protocol-refs report)
                   :test #'string= :key #'status-protocol-ref-name)))
      (assert (eq :orphan (status-protocol-ref-status registration)))
      (assert (not (status-report-ok-p report))))))

(defun %test-diagnostic-finds-isolated-registration ()
  (dolist (backend '("files" "reftable"))
    (with-temporary-directory (directory)
      (call-git (list "init" "--bare" "--quiet"
                      (format nil "--ref-format=~A" backend)
                      (namestring directory)))
      (%status-git directory "symbolic-ref"
                   "refs/gaw/heads/orphan" "refs/heads/orphan")
      (assert (status-report-ok-p (status directory)))
      (assert (not (zerop (diagnose-status directory)))))))

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
             (assert (equal
                      '("fsck" "--connectivity-only" "--no-reflogs"
                        "--no-dangling" "--no-progress")
                      (first seen)))
             (assert (equal directory (second seen))))
        (setf (symbol-function symbol) original)))))

(defun run-tests ()
  (%test-ordinary-repository)
  (%test-initialized-repository-and-nested-cwd)
  (%test-protocol-anomalies)
  (%test-selector-discovers-hidden-registration)
  (%test-ordinary-and-invalid-marker-branches)
  (%test-existing-branch-discovers-hidden-registration)
  (%test-unknown-ref-is-informational)
  (%test-hook-conflict-is-protocol-error)
  (%test-bare-repository)
  (%test-reftable-report)
  (%test-diagnostic-finds-isolated-registration)
  (%test-diagnostic-arguments-and-result)
  (format t "~&All status tests passed.~%")
  t)
