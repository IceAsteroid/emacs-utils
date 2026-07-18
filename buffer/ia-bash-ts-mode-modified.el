;;; ia-bash-ts-mode-modified.el --- Extra & Modified features for bash-ts-mode  -*- lexical-binding: t; -*-


;;; Commentary:
;; 

;;; Code:

(defun ia-hook/bash-ts-mode-enhanced ()
  "Show variables for `imenu'.

More features can be added here."
  (let ((safe-extract
         (lambda (node)
           (let ((name-node (treesit-node-child-by-field-name node "name")))
             (if name-node
                 ;; 1. Standard approach: grab the "name" field
                 (treesit-node-text name-node t)
               ;; 2. Fallback for variables: the 0th child is the variable name itself
               (treesit-node-text (treesit-node-child node 0 t) t))))))
    (setq treesit-simple-imenu-settings
          `(("Functions" "\\`function_definition\\'" nil ,safe-extract)
            ("Variables" "\\`variable_assignment\\'" nil ,safe-extract)))))

(define-minor-mode ia/bash-ts-modified-mode
  "Toggle extra & modified features for `bash-ts-mode'."
  :global t
  :group 'treesit
  (cond
   (ia/bash-ts-modified-mode
    (add-hook 'bash-ts-mode-hook #'ia-hook/bash-ts-mode-enhanced))
   (t
    (remove-hook 'bash-ts-mode-hook 'ia-hook/bash-ts-mode-enhanced))))

(provide 'ia-bash-ts-mode-modified)

;;; ia-bash-ts-mode-modified.el ends here
