;;; ia-help-modified.el --- Help mode modified features  -*- lexical-binding: t; -*-

;;; Commentary:
;; Unfinished.
;; Enhances the built-in help system with additional metadata.

;;; Code:

(eval-and-compile
  (defvar ia/help-modified-mode nil))

(defgroup ia/help-modified nil
  "Customizations for modifying the built-in help system."
  :group 'help)

(defun ia/hl-md--update-hooks ()
  "Add or remove help hooks based on current configuration and mode state."
  (if (and ia/help-modified-mode ia/hl-md-customizable-status)
      (add-hook 'help-fns-describe-variable-functions #'ia/hl-md-insert-customizable-status)
    (remove-hook 'help-fns-describe-variable-functions #'ia/hl-md-insert-customizable-status)))

(defcustom ia/hl-md-customizable-status nil
  "Non-nil to insert text to denote if a variable is customizable or not."
  :group 'ia/help-modified
  :type 'boolean
  :set (lambda (sym val)
         (set-default sym val)
         (ia/hl-md--update-hooks)))

(defun ia/hl-md-insert-customizable-status (variable)
  "Insert an explicit customization status line below the header.
Designed for `help-fns-describe-variable-functions'."
  (with-current-buffer standard-output ;; CRUCIAL: Directs modifications to the help buffer
    (let ((inhibit-read-only t))     ;; Ensure we can write to it
      (save-excursion
        (goto-char (point-min))
        ;; Search for the first blank line separating header from docstring
        (when (re-search-forward "^$" nil t)
          (insert "\nUser customizable: "
                  (if (custom-variable-p variable) "Yes" "No")))))))

;;;###autoload
(define-minor-mode ia/help-modified-mode
  "Features to modify the built-in help system."
  :group 'ia/help-modified
  :global t
  (ia/hl-md--update-hooks)
  ;; Placeholder code for future features.
  (if ia/help-modified-mode
      t
    nil))

(provide 'ia-help-modified)

;;; ia-help-modified.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("ia/hl-md-" . "ia/help-modified-"))
;; End:
