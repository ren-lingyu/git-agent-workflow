(in-package #:git-agent-workflow/tests)

(defmacro signals (condition-type &body body)
  `(handler-case
       (progn
         ,@body
         nil)
     (,condition-type ()
       t)))

(defun call-git (args &key ignore-error-status)
  (uiop:run-program
   (cons "git"
         args)
   :output '(:string :stripped t)
   :error-output '(:string :stripped t)
   :ignore-error-status ignore-error-status
   :force-shell nil))

(defun write-test-octets (pathname octets)
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create
                          :element-type '(unsigned-byte 8))
    (write-sequence octets
                    stream))
  pathname)

(defmacro with-temporary-directory ((directory) &body body)
  `(let ((,directory
           (uiop:merge-pathnames*
            (format nil
                    "git-agent-workflow test ~36R-~36R/"
                    (get-universal-time)
                    (random most-positive-fixnum))
            (uiop:temporary-directory))))
     (ensure-directories-exist
      (merge-pathnames "placeholder"
                       ,directory))
     (unwind-protect
          (progn
            ,@body)
       (uiop:delete-directory-tree
        ,directory
        :validate t
        :if-does-not-exist :ignore))))

(defmacro with-test-repository ((directory) &body body)
  `(with-temporary-directory (,directory)
     (call-git (list "init"
                     "--quiet"
                     (namestring ,directory)))
     ,@body))
