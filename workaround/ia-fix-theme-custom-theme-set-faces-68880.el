;;; ia-fix-theme.el --- Fix `custom-theme-set-faces' for themes  -*- lexical-binding: t; -*-

;;; Commentary:
;; `custom-theme-set-faces' does not work for a theme except 'user
;; Emacs Bug #68880 for pgtk build, as of <2026-06-10 Wed>.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/custom-theme-set-faces t
  (defvar ia-fix/theme-face-overrides nil
    "Alist storing face overrides for each theme.")

  (defun ia-fix/custom-theme-set-faces (theme &rest args)
    "Generic, drop-in replacement for `custom-theme-set-faces`.
Stores the settings and forces a PGTK cache refresh to prevent staleness."
    ;; 1. Store & deduplicate the settings so they persist across theme toggles
    (let ((theme-overrides (alist-get theme ia-fix/theme-face-overrides)))
      (dolist (entry args)
        (setq theme-overrides (cons entry (assq-delete-all (car entry) theme-overrides))))
      (setf (alist-get theme ia-fix/theme-face-overrides) theme-overrides))
    ;; 2. Apply settings using the native function immediately
    (apply #'custom-theme-set-faces theme args)
    ;; 3. If the theme is currently active, force the Wayland/PGTK refresh
    (when (memq theme custom-enabled-themes)
      (dolist (entry args)
        (face-spec-recalc (car entry) (selected-frame)))))

  ;; 4. The single generic hook that watches all themes
  (defun ia-hook/apply-generic-theme-overrides (theme)
    "Automatically reapplies stored overrides when ANY theme is enabled."
    (let ((overrides (alist-get theme ia-fix/theme-face-overrides)))
      (when overrides
        (apply #'custom-theme-set-faces theme overrides)
        (dolist (entry overrides)
          (face-spec-recalc (car entry) (selected-frame))))))
  ;; Attach the hook permanently
  (add-hook 'enable-theme-functions 'ia-hook/apply-generic-theme-overrides))

(provide 'ia-fix-theme)

;;; ia-fix-theme.el ends here
