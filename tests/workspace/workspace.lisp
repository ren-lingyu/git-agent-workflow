(in-package #:git-agent-workflow/tests.workspace)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %octets (text)
  (string-to-octets text :encoding :utf-8))

(defun %test-index-snapshot-and-validation ()
  (with-test-repository (directory)
    (write-test-octets (merge-pathnames ".gaw/config" directory)
                       (%octets "(:workspace ((:directory \"notes\")))"))
    (write-test-octets (merge-pathnames "notes/one" directory)
                       (%octets "one"))
    (%git directory "add" "--" ".gaw/config" "notes/one")
    (let ((entries (read-index-snapshot directory)))
      (assert (string= "040000"
                       (git-entry-mode
                        (entry-at-path (%octets "notes") entries))))
      (assert (equal '((:directory . "notes"))
                     (validate-workspace '((:directory . "notes")) entries))))
    (write-test-octets (merge-pathnames "outside" directory) (%octets "x"))
    (%git directory "add" "--" "outside")
    (assert (handler-case
                (progn
                  (validate-workspace '((:directory . "notes"))
                                      (read-index-snapshot directory))
                  nil)
              (workspace-error () t)))))

(defun %test-public-package-boundary ()
  (let ((package (find-package '#:git-agent-workflow.workspace)))
    (dolist (name '("READ-TREE-SNAPSHOT" "READ-INDEX-SNAPSHOT"
                    "VALIDATE-WORKSPACE" "FIND-PROJECT-PATH-CONFLICT"
                    "WORKSPACE-ERROR" "WORKSPACE-ERROR-REASON"))
      (multiple-value-bind (symbol status) (find-symbol name package)
        (assert symbol)
        (assert (eq status :external))))))

(defun run-tests ()
  (%test-index-snapshot-and-validation)
  (%test-public-package-boundary)
  (format t "~&All workspace tests passed.~%")
  t)
