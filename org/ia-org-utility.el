;;; ia-org-utility.el --- Small custom snippets for org-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

;;; Code:

(defun ia/org-toggle-emphasis-display ()
  "Fast buffer-wide toggle of `org-hide-emphasis-markers`."
  (interactive)
  (setq-local org-hide-emphasis-markers (not org-hide-emphasis-markers))
  ;; Flushes the font-lock without restarting the entire major mode
  (font-lock-flush)
  (message "Buffer emphasis markers %s."
           (if org-hide-emphasis-markers "hidden" "visible")))

(provide 'ia-org-utility)

;;; ia-org-utility.el ends here
