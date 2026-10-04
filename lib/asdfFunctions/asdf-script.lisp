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

(defun skill-name-p (name)
  (and (plusp (length name))
       (every (lambda (character)
                (or (and (char<= #\a character)
                         (char<= character #\z))
                    (and (char<= #\0 character)
                         (char<= character #\9))
                    (char= character #\-)))
              name)))

(defun skill-static-files (component)
  (cond
    ((typep component 'asdf:module)
     (loop for child in (asdf:component-children component)
           append (skill-static-files child)))
    ((typep component 'asdf:static-file)
     (list component))
    (t
     (error "Unexpected non-static skill component: ~A"
            (asdf:component-name component)))))

(defun write-skill-manifest (system output-path)
  (let ((skills (asdf:find-component system '("share" "skills"))))
    (with-open-file (stream output-path
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :external-format :utf-8)
      (when skills
        (unless (typep skills 'asdf:module)
          (error "ASDF share/skills component must be a module"))
        (dolist (skill (asdf:component-children skills))
          (unless (typep skill 'asdf:module)
            (error "Each ASDF skill component must be a module"))
          (let* ((name (asdf:component-name skill))
                 (root (namestring (truename
                                    (asdf:component-pathname skill))))
                 (files (skill-static-files skill))
                 (seen (make-hash-table :test #'equal)))
            (unless (skill-name-p name)
              (error "Invalid ASDF skill name: ~S" name))
            (dolist (file files)
              (let ((source
                      (namestring (truename
                                   (asdf:component-pathname file)))))
                (unless (and (< (length root) (length source))
                             (string= root source
                                      :end2 (length root)))
                  (error "Skill file escapes its ASDF skill directory: ~A"
                         source))
                (let ((relative (subseq source (length root))))
                  (when (gethash relative seen)
                    (error "Duplicate ASDF skill file: ~A" relative))
                  (setf (gethash relative seen) t)
                  (dolist (field (list name relative source))
                    (write-string field stream)
                    (write-char #\Null stream)))))
            (unless (gethash "SKILL.md" seen)
              (error "ASDF skill ~S does not declare SKILL.md" name))))))))

(let ((asd-file (truename @asdName@)))
  (asdf:load-asd asd-file)
  (let ((system
          (primary-system-defined-by asd-file)))
    @body@))
