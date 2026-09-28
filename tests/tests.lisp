(in-package #:git-agent-workflow/tests)

(defun run-tests ()
  (git-agent-workflow/tests.git:run-tests)
  (git-agent-workflow/tests.refs:run-tests)
  t)
