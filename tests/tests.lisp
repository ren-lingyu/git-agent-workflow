(in-package #:git-agent-workflow/tests)

(defun run-tests ()
  (git-agent-workflow/tests.git:run-tests)
  (git-agent-workflow/tests.refs:run-tests)
  (git-agent-workflow/tests.config:run-tests)
  (git-agent-workflow/tests.commit:run-tests)
  (git-agent-workflow/tests.cli:run-tests)
  t)
