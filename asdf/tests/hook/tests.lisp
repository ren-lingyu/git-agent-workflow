(in-package #:git-agent-workflow/tests.hook)

(defun run-tests ()
  (%run-hook-tests)
  (%run-hook-integration-tests)
  t)
