;;; ia-pdf-tools-modified.el --- Additional & Modified Features of Pdf-tools  -*- lexical-binding: t; -*-

;;; Commentary:
;; Unfinished.

(require 'pdf-tools)

;;; Code:

(defgroup ia/pdf-tools-modified nil
  "Additional & modified features of `pdf-tools'."
  :group 'pdf-tools)

;; --- TODO Implemented: Custom Variable ---
(defcustom ia/pt-md-update-on-theme-change t
  "If non-nil, automatically update PDF themes when Emacs theme changes."
  :type 'boolean
  :group 'ia/pdf-tools-modified)

(defvar ia/pt-md--theme-switch-timer nil
  "Idle timer to run `ia/pt-md-view-update-theme'.")

;; --- Buffer Update Logic ---
(defun ia/pt-md-view-update-theme ()
  "Update theme for all active pdf-view buffers."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'pdf-view-mode)
        ;; Cycle the mode to force pdf-tools to redraw with the new background colors
        (pdf-view-themed-minor-mode -1)
        (pdf-view-themed-minor-mode 1)))))

(defun ia/pt-md-setup-theme-switch-update-timer (&rest _)
  "Update the timer `ia/pt-md--theme-switch-timer' on demand.
Obeys the user preference in `ia/pt-md-update-on-theme-change'."
  (when ia/pt-md-update-on-theme-change
    (when (timerp ia/pt-md--theme-switch-timer)
      (cancel-timer ia/pt-md--theme-switch-timer))
    (setq ia/pt-md--theme-switch-timer
          (run-with-idle-timer 0.05 nil #'ia/pt-md-view-update-theme))))

;; --- Local Setup ---
(defun ia/pt-md-local-setup ()
  "Local setup applied strictly to the current PDF buffer."
  (pdf-view-themed-minor-mode 1)
  ;; Any future local settings (like auto-slice) go here.
  )

;; --- Global Minor Mode ---
(define-minor-mode ia/pdf-tools-modified-mode
  "Additional & modified features of `pdf-tools'."
  :global t
  :group 'ia/pdf-tools-modified
  (if ia/pdf-tools-modified-mode
      (progn
        ;; 1. Attach Local setup to the mode hook
        (add-hook 'pdf-view-mode-hook #'ia/pt-md-local-setup)
        ;; 2. Attach Global theme listeners
        (add-hook 'enable-theme-functions #'ia/pt-md-setup-theme-switch-update-timer)
        (add-hook 'disable-theme-functions #'ia/pt-md-setup-theme-switch-update-timer))
    ;; CLEANUP: Symmetrically remove everything we just added
    (remove-hook 'pdf-view-mode-hook #'ia/pt-md-local-setup)
    (remove-hook 'enable-theme-functions #'ia/pt-md-setup-theme-switch-update-timer)
    (remove-hook 'disable-theme-functions #'ia/pt-md-setup-theme-switch-update-timer)
    (when (timerp ia/pt-md--theme-switch-timer)
      (cancel-timer ia/pt-md--theme-switch-timer))))


(provide 'ia-pdf-tools-modified)

;;; ia-pdf-tools-modified.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("ia/pt-md-" . "ia/pdf-tools-modified-"))
;; End:
