(asdf:defsystem "skill-install-fixture"
  :components ((:module "src"
                :pathname "src/"
                :components ((:file "main")
                             (:module "help"
                              :pathname "help/"
                              :components
                              ((:module "text"
                                :pathname "text/"
                                :components
                                ((:static-file "overview.txt")))))))
               (:module "share"
                :pathname "share/"
                :components
                ((:module "skills"
                  :pathname "skills/"
                  :components
                  ((:module "sample-skill"
                    :pathname "sample-skill/"
                    :components
                    ((:static-file "SKILL.md")
                     (:module "references"
                      :pathname "references/"
                      :components ((:static-file "guide.md"))))))))))
  :build-operation program-op
  :build-pathname "fixture-program"
  :entry-point "cl-user::main")
