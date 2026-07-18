;;; ia-combobulate-bash.el --- Bash mode support for Combobulate  -*- lexical-binding: t; -*-

(require 'combobulate-settings)
(require 'combobulate-navigation)
(require 'combobulate-manipulation)
(require 'combobulate-interface)
(require 'combobulate-rules)
(require 'combobulate-setup)

(defun combobulate-bash-pretty-print-node-name (node default-name)
  "Pretty print the node name for Bash mode, forcing UI names for missing dictionaries."
  (let ((type (combobulate-node-type node)))
    (pcase type
      ("function_definition" 
       ;; Safely try to get the function name
       (let ((name-node (combobulate-node-child-by-field node "name")))
         (if name-node
             (concat "Function [" (combobulate-node-text name-node) "]")
           "Function")))
      ("command" 
       ;; Show a truncated preview of the actual bash command
       (combobulate-string-truncate (combobulate-node-text node) 40))
      (_ 
       ;; THE UI FIX: If Combobulate doesn't know the name (default-name is nil),
       ;; we dynamically generate a clean name (e.g., "if_statement" -> "If Statement")
       (or default-name
           (capitalize (replace-regexp-in-string "_" " " type)))))))

(eval-and-compile
  (defvar combobulate-bash-definitions
    '(
      ;; THE TRIGGER FIX: We must include the nodes our cursor rests on!
      (context-nodes
       '("string" "raw_string" "word"))

      (pretty-print-node-name-function #'combobulate-bash-pretty-print-node-name)

      (procedures-sexp
       '((:activation-nodes ((:nodes ("command" "pipeline" "if_statement" "elif_clause" "else_clause" "while_statement" "for_statement" "case_statement" "function_definition" "variable_assignment" "list" "compound_statement"))))))

      (procedures-defun
       '((:activation-nodes ((:nodes ("function_definition"))))))

      (procedures-sibling
       '((:activation-nodes
          ((:nodes ("word" "command" "pipeline" "if_statement" "elif_clause" "else_clause" "while_statement" "for_statement" "case_statement" "function_definition" "variable_assignment" "list") :position at))
          :selector (:choose node :match-children t))))

      (procedures-hierarchy
       '((:activation-nodes
          ((:nodes ("word" "command" "pipeline" "if_statement" "elif_clause" "else_clause" "while_statement" "for_statement" "case_statement" "function_definition" "variable_assignment" "list" "compound_statement" "do_group" "then_clause" "program") :position at))
          :selector (:choose node :match-children t))))

      ;; (procedures-logical
      ;;  '((:activation-nodes ((:nodes ("command" "pipeline" "if_statement" "elif_clause" "else_clause" "while_statement" "for_statement" "case_statement" "function_definition" "variable_assignment" "list")))))))))

      ;; LOGICAL: This drives the ASCII UI tree! We MUST include "program" (the root).
      ;; We only include the major structural nodes here so the UI tree stays clean.
      (procedures-logical
       '((:activation-nodes
          ((:nodes ("program" "function_definition" "if_statement" "elif_clause" "else_clause" "while_statement" "for_statement" "case_statement" "command" "pipeline" "variable_assignment")))))))))

(define-combobulate-language
 :name bash
 :language bash
 :major-modes (bash-ts-mode sh-mode)
 :custom combobulate-bash-definitions
 :setup-fn combobulate-bash-setup)

(defun combobulate-bash-setup (_))

(provide 'ia-combobulate-bash)
;;; ia-combobulate-bash.el ends here
