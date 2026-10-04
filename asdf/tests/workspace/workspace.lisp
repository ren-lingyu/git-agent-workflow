(in-package #:git-agent-workflow/tests.workspace)

(defun %git (directory &rest arguments)
  (call-git (append (list "-C" (namestring directory)) arguments)))

(defun %octets (text)
  (string-to-octets text :encoding :utf-8))

(defun %index-record (path &optional (stage 0))
  (concatenate '(vector (unsigned-byte 8))
               (%octets
                (format nil
                        "100644 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ~D~C"
                        stage
                        #\Tab))
               path
               (make-array 1
                           :element-type '(unsigned-byte 8)
                           :initial-element 0)))

(defun %parse-index-records (octets)
  (git-agent-workflow.workspace::%parse-records
   octets
   (lambda (records start end)
     (git-agent-workflow.workspace::%parse-index-record
      records start end "160000" "blob" "commit"))))

(defun %test-index-records-preserve-path-octets ()
  (let* ((paths
           (list (make-array 8
                             :element-type '(unsigned-byte 8)
                             :initial-contents '(116 97 98 9 112 97 116 104))
                 (make-array 12
                             :element-type '(unsigned-byte 8)
                             :initial-contents
                             '(108 105 110 101 10 98 114 101 97 107 47 120))
                 (make-array 5
                             :element-type '(unsigned-byte 8)
                             :initial-contents '(114 97 119 255 120))))
         (records
           (%parse-index-records
            (apply #'concatenate
                   '(vector (unsigned-byte 8))
                   (mapcar #'%index-record paths)))))
    (assert (= (length paths) (length records)))
    (mapc (lambda (path record)
            (assert (equalp path (git-entry-path record))))
          paths
          records)
    (assert
     (handler-case
         (progn
           (%parse-index-records
            (subseq (%index-record (first paths))
                    0
                    (1- (length (%index-record (first paths))))))
           nil)
       (error () t)))))

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
  (%test-index-records-preserve-path-octets)
  (%test-index-snapshot-and-validation)
  (%test-public-package-boundary)
  (format t "~&All workspace tests passed.~%")
  t)
