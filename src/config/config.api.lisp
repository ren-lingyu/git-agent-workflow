(in-package #:git-agent-workflow.config)

(eval-when (:load-toplevel :execute)
  (dolist (function '(%read-config
                      current-ref))
    (unless (fboundp function)
      (error "Required config API dependency is unavailable: ~S"
             function))))

(defconstant +maximum-config-size+
  65536)

(defconstant +maximum-list-depth+
  16)

(defconstant +maximum-workspace-entries+
  1024)

(defconstant +maximum-workspace-path-size+
  4096)

(defun read-config (directory)
  (%read-config ".gaw/config"
                (current-ref directory)
                directory
                +maximum-config-size+
                +maximum-list-depth+
                +maximum-workspace-entries+
                +maximum-workspace-path-size+))
