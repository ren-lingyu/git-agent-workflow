(in-package #:git-agent-workflow/tests.undeploy)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %test-healthy-and-idempotent ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let ((tip (%git directory "rev-parse" "refs/heads/gaw"))
          (first (undeploy directory)))
      (assert (undeploy-result-ok-p first))
      (assert (undeploy-result-removed-selector-p first))
      (assert (string= tip (%git directory "rev-parse" "refs/heads/gaw")))
      (assert (= 2 (nth-value 2
                            (call-git (list "-C" (namestring directory)
                                            "show-ref" "--exists"
                                            "refs/gaw/HEAD")
                                      :ignore-error-status t))))
      (assert (undeploy-result-ok-p (undeploy directory))))))

(defun %test-corrupt-selector-and-safe-legacy-cleanup ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/HEAD" "refs/heads/missing")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/heads/gaw" "refs/heads/gaw")
    (let ((result (undeploy directory)))
      (assert (undeploy-result-ok-p result))
      (assert (undeploy-result-removed-selector-p result))
      (assert (equal '("refs/gaw/heads/gaw")
                     (undeploy-result-removed-legacy-refs result))))))

(defun %test-unsafe-legacy-ref-is-preserved ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
          "symbolic-ref" "refs/gaw/heads/gaw" "refs/heads/other")
    (let ((result (undeploy directory)))
      (assert (not (undeploy-result-ok-p result)))
      (assert (undeploy-result-residuals result))
      (assert (string= "refs/heads/other"
                       (%git directory "symbolic-ref"
                             "refs/gaw/heads/gaw")))
      (assert (= 2 (nth-value 2
                            (call-git (list "-C" (namestring directory)
                                            "show-ref" "--exists"
                                            "refs/gaw/HEAD")
                                      :ignore-error-status t)))))))

(defun %test-direct-selector-is-removed-but-direct-legacy-is-preserved ()
  (with-test-repository (directory)
    (initialize directory :branch "gaw")
    (let ((tip (%git directory "rev-parse" "refs/heads/gaw")))
      (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
            "update-ref" "--no-deref" "refs/gaw/HEAD" tip)
      (%git directory "-c" "hook.gaw-reference-transaction.enabled=false"
            "update-ref" "refs/gaw/heads/gaw" tip)
      (let ((result (undeploy directory)))
        (assert (undeploy-result-removed-selector-p result))
        (assert (not (undeploy-result-ok-p result)))
        (assert (string= tip (%git directory "rev-parse"
                                 "refs/gaw/heads/gaw")))
        (assert (string= tip (%git directory "rev-parse"
                                 "refs/heads/gaw")))))))

(defun run-tests ()
  (%test-healthy-and-idempotent)
  (%test-corrupt-selector-and-safe-legacy-cleanup)
  (%test-unsafe-legacy-ref-is-preserved)
  (%test-direct-selector-is-removed-but-direct-legacy-is-preserved)
  (format t "~&All undeploy tests passed.~%")
  t)
