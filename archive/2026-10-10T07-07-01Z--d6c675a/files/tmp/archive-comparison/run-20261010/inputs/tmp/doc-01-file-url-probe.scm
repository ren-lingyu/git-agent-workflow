(load "/home/lingyu/Projects/org-texmacs/org-texmacs-worker.scm")

(define (org-texmacs-parse-reply request)
  (list 'ok (cadr request)
        (cons 'url-probe
              (map
               (lambda (path)
                 (catch #t
                   (lambda ()
                     (let* ((url-text (url->string (system->url path)))
                            (native (org-texmacs-encode-body
                                     (list 'hlink "description" url-text) '()))
                            (target (caddr native)))
                       (list 'case path url-text
                             (url->system (string->url url-text))
                             (org-texmacs-hex-tree target)
                             (org-texmacs-hex-tree
                              (url->system (string->url target)))
                             (url->system (string->url (cork->utf8 target))))))
                   (lambda args (list 'failure path (object->string args)))))
               '("/tmp/org-resource/a.pdf"
                 "/tmp/org-resource/a b#c?d%.pdf"
                 "/tmp/org-resource/中-é.pdf"
                 "/tmp/org-resource/<alpha>.pdf")))))
