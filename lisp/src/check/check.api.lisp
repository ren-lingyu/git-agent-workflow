(in-package #:git-agent-workflow.check)

(eval-when (:load-toplevel :execute)
  (unless (fboundp '%check-runtime)
    (error "Required check API dependency is unavailable: ~S" '%check-runtime)))

(defparameter *config-path* ".gaw/config")
(defparameter *selector-ref* "refs/gaw/HEAD")

(defun check (directory)
  (handler-case
      (%check-runtime directory *config-path* *selector-ref*)
    (check-error (condition)
      (error condition))
    (error (condition)
      (%signal-check-error :runtime-failure "~A" condition))))
