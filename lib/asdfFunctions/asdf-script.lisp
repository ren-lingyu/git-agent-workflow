(require "asdf")

(defun systems-defined-by (asd-file)
  (let ((systems '()))
    (asdf:map-systems
     (lambda (system)
       (let ((source-file
               (asdf:system-source-file system)))
         (when (and source-file
                    (equal (truename source-file)
                           asd-file))
           (push system systems)))))
    systems))

(defun primary-system-defined-by (asd-file)
  (let ((systems
          (remove-if
           (lambda (system)
             (find #\/
                   (asdf:component-name system)))
           (systems-defined-by asd-file))))
    (unless (= (length systems) 1)
      (error
       "Expected exactly one primary ASDF system in ~A, found: ~{~A~^, ~}"
       asd-file
       (mapcar #'asdf:component-name systems)))
    (first systems)))

(let ((asd-file (truename @asdName@)))
  (asdf:load-asd asd-file)
  (let ((system
          (primary-system-defined-by asd-file)))
    @body@))
