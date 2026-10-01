(in-package #:git-agent-workflow/tests.refs)

(defun run-tests ()
  (%run-ref-tests)
  (%run-current-ref-tests)
  t)
