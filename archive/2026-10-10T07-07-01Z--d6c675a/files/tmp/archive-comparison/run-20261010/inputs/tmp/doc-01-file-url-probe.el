;;; doc-01-file-url-probe.el --- Native file URL probe -*- lexical-binding: t; -*-
(load "/home/lingyu/Projects/org-texmacs/tests/ert/ert.el" nil t)
(let ((org-texmacs--worker-scheme-file
       "/home/lingyu/Projects/org-texmacs/tmp/doc-01-file-url-probe.scm"))
  (org-texmacs-test--with-worker
    (let ((result (org-texmacs--worker-request "\"probe\"")))
      (with-temp-file "/home/lingyu/Projects/org-texmacs/tmp/doc-01-file-url-probe.txt"
        (let ((print-length nil) (print-level nil))
          (prin1 result (current-buffer))
          (terpri (current-buffer))))
      (prin1 result)
      (terpri))))
