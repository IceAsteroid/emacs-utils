;;; ia-fix-theme-custom-theme-set-faces-68880.el --- Fix `custom-theme-set-faces' for themes  -*- lexical-binding: t; -*-

;;; Commentary:
;; `custom-theme-set-faces' does not work for a theme except 'user
;; Emacs Bug #68880, reported on a pgtk build, as of <2026-06-10 Wed>.
;;
;; The root cause is Lisp-level, not pgtk-specific: since the
;; "apply-only-user" change (commit aabaa9f8c8b7) `custom--should-apply-setting'
;; returns nil for an enabled theme other than `user', so
;; `custom-theme-set-faces' only records the setting without applying it
;; (Bug#76685).
;;
;; The bug was fixed upstream in Emacs 31.1 (Bug#76685, commit
;; 203747b87fbf, "Allow changing theme settings without reloading it").
;; The workaround below therefore only exists on the affected versions
;; (28 < version < 31); enable it explicitly with
;; `(ia-fix/theme-custom-theme-set-faces-68880-mode 1)'.  On other
;; versions the mode is a no-op and the native function applies settings
;; immediately.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/theme-custom-theme-set-faces-68880 (and (> emacs-major-version 28)
                                                              (< emacs-major-version 31))
  ;; Capture the native function before any alias is installed, so the
  ;; workaround can delegate to it without infinite recursion.
  (defvar ia-fix/theme-custom-theme-set-faces-68880--native-custom-theme-set-faces
    (symbol-function 'custom-theme-set-faces)
    "Native `custom-theme-set-faces' function object, captured before aliasing.")

  (defvar ia-fix/theme-custom-theme-set-faces-68880--theme-face-overrides nil
    "Alist storing face overrides for each theme.")

  (defun ia-fix/theme-custom-theme-set-faces-68880 (theme &rest args)
    "Generic, drop-in replacement for `custom-theme-set-faces'.
Stores the settings and forces a PGTK cache refresh to prevent staleness."
    ;; 1. Store & deduplicate the settings so they persist across theme toggles
    (let ((theme-overrides (alist-get theme ia-fix/theme-custom-theme-set-faces-68880--theme-face-overrides)))
      (dolist (entry args)
        (setq theme-overrides (cons entry (assq-delete-all (car entry) theme-overrides))))
      (setf (alist-get theme ia-fix/theme-custom-theme-set-faces-68880--theme-face-overrides) theme-overrides))
    ;; 2. Apply settings using the native function immediately
    (apply ia-fix/theme-custom-theme-set-faces-68880--native-custom-theme-set-faces theme args)
    ;; 3. If the theme is currently active, force the Wayland/PGTK refresh
    (when (memq theme custom-enabled-themes)
      (dolist (entry args)
        (face-spec-recalc (car entry) (selected-frame)))))

  ;; 4. The single generic hook that watches all themes
  (defun ia-hook/theme-custom-theme-set-faces-68880-apply-generic-theme-overrides (theme)
    "Automatically reapplies stored overrides when ANY theme is enabled."
    (let ((overrides (alist-get theme ia-fix/theme-custom-theme-set-faces-68880--theme-face-overrides)))
      (when overrides
        (apply ia-fix/theme-custom-theme-set-faces-68880--native-custom-theme-set-faces theme overrides)
        (dolist (entry overrides)
          (face-spec-recalc (car entry) (selected-frame))))))

  ;; 5. Install/uninstall the alias + hook (used by
  ;;    `ia-fix/theme-custom-theme-set-faces-68880-mode').
  (defun ia-fix/theme-custom-theme-set-faces-68880--set (enabled)
    "Enable or disable the Bug#68880 workaround according to ENABLED."
    (if enabled
        (add-hook 'enable-theme-functions #'ia-hook/theme-custom-theme-set-faces-68880-apply-generic-theme-overrides)
      (remove-hook 'enable-theme-functions #'ia-hook/theme-custom-theme-set-faces-68880-apply-generic-theme-overrides))
    (defalias 'custom-theme-set-faces
      (if enabled #'ia-fix/theme-custom-theme-set-faces-68880
        ia-fix/theme-custom-theme-set-faces-68880--native-custom-theme-set-faces))))

;;;###autoload
(define-minor-mode ia-fix/theme-custom-theme-set-faces-68880-mode
  "Fix `custom-theme-set-faces' for themes other than `user' (Bug#68880).

On Emacs versions affected by the bug (28 < version < 31),
`custom-theme-set-faces' only records settings for a theme other than
`user' instead of applying them.  Enabling this mode aliases
`custom-theme-set-faces' to the workaround and attaches the reapply
hook; disabling restores the native function.

On other Emacs versions this mode has no effect, because the bug does
not exist there (fixed upstream in 31.1, Bug#76685)."
  :global t
  :lighter nil
  :group 'customize
  ;; `ia-fix/theme-custom-theme-set-faces-68880--set' only exists on
  ;; affected versions (inside the version-gated chunk); call it
  ;; dynamically so the mode is a no-op elsewhere without compiler
  ;; warnings.
  (when (fboundp 'ia-fix/theme-custom-theme-set-faces-68880--set)
    (funcall 'ia-fix/theme-custom-theme-set-faces-68880--set
             ia-fix/theme-custom-theme-set-faces-68880-mode)))

(provide 'ia-fix-theme-custom-theme-set-faces-68880)

;;; ia-fix-theme-custom-theme-set-faces-68880.el ends here
