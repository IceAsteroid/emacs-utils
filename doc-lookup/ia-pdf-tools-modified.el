;;; ia-pdf-tools-modified.el --- Additional & Modified Features of Pdf-tools  -*- lexical-binding: t; -*-

;;; Commentary:

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
  "Idle timer to run `ia/pt-md-view-update-theme-all-buffers'.")

;; --- Buffer Update Logic ---
(defun ia/pt-md--update-buffer-theme ()
  "Refresh the current PDF buffer with the current Emacs theme.

Apply the theme's `default' foreground and background, clear the
buffer's image cache, and redisplay the buffer's live windows via
`pdf-view-refresh-themed-buffer'.

A window that shows the buffer from a non-current `tab-bar-mode' tab
is not live -- it is detached from every frame and only kept alive by
the tab's window configuration -- so `pdf-view-refresh-themed-buffer'
cannot redisplay it.  Flag such windows with
`pdf-view-window-needs-redisplay'; once their tab becomes current the
window turns live, the buffer-local `window-configuration-change-hook'
entry `pdf-view-redisplay-some-windows' runs, and pdf-tools redisplays
the window with the new theme."
  (pdf-view-refresh-themed-buffer t)
  (dolist (winprops image-mode-winprops-alist)
    (let ((window (car-safe winprops)))
      (when (and (windowp window)
                 (not (window-live-p window)))
        (setf (pdf-view-window-needs-redisplay window) t)))))

(defun ia/pt-md--pdf-buffers ()
  "Return a list of buffers whose major mode derives from `pdf-view-mode'."
  (let (buffers)
    (dolist (buf (buffer-list))
      (when (provided-mode-derived-p
             (buffer-local-value 'major-mode buf)
             'pdf-view-mode)
        (push buf buffers)))
    (nreverse buffers)))

(defun ia/pt-md-view-update-theme-all-buffers ()
  "Update the theme of all `pdf-view-mode' buffers."
  (dolist (buf (ia/pt-md--pdf-buffers))
    (with-current-buffer buf
      (ia/pt-md--update-buffer-theme))))

(defun ia/pt-md-setup-theme-switch-update-timer (&rest _)
  "Update the timer `ia/pt-md--theme-switch-timer' on demand.
Obeys the user preference in `ia/pt-md-update-on-theme-change'."
  (when ia/pt-md-update-on-theme-change
    (when (timerp ia/pt-md--theme-switch-timer)
      (cancel-timer ia/pt-md--theme-switch-timer))
    (setq ia/pt-md--theme-switch-timer
          (run-with-idle-timer 0.05 nil #'ia/pt-md-view-update-theme-all-buffers))))

;; --- Local Setup ---
(defun ia/pt-md-local-setup ()
  "Local setup applied strictly to the current PDF buffer.

Settings not related to this modification belong in the init file that
sets up pdf-tools."
  ;; (pdf-view-themed-minor-mode 1)
  ;; Any future local settings (like auto-slice) go here.
  )

;; --- Global Minor Mode ---
(define-minor-mode ia/pdf-tools-modified-mode
  "Additional & modified features of `pdf-tools'."
  :global t
  :group 'ia/pdf-tools-modified
  (if ia/pdf-tools-modified-mode
      (progn
        ;; Attach the per-buffer setup to `pdf-view-mode-hook'.
        (add-hook 'pdf-view-mode-hook #'ia/pt-md-local-setup)
        ;; Listen for theme changes.
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
