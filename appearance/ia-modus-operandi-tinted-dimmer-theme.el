;;; ia-modus-operandi-tinted-dimmer-theme.el --- Modified Dimmer Version  -*- lexical-binding: t; -*-

(require 'modus-themes)

;;; Commentary:
;; 

;;; Code:

;;;###autoload
;; Add themes from this package to the `custom-theme-load-path'
(when load-file-name
  (let ((dir (file-name-directory load-file-name)))
      (add-to-list 'custom-theme-load-path dir)))

(defvar ia/modus-operandi-tinted-dimmer-palette-overrides
  '((bg-main "#e7e4dc")
    (bg-dim "#dedad4")
    (bg-popup "#e7decf")
    (cursor "SeaGreen"))
  "Palette overrides for `modus-operandi-tinted-dimmer'.")

(defvar ia/modus-operandi-tinted-dimmer-palette-user nil
  "User palette extensions for `modus-operandi-tinted-dimmer'.")

(modus-themes-theme
 'ia-modus-operandi-tinted-dimmer
 'modus-themes
 "Modified version with dimmer background for `modus-operandi-tinted-theme'."
 'light
 'modus-operandi-tinted-palette
 'ia/modus-operandi-tinted-dimmer-palette-user
 'ia/modus-operandi-tinted-dimmer-palette-overrides)

(provide 'ia-modus-operandi-tinted-dimmer-theme)


;;; ia-modus-operandi-tinted-dimmer-theme.el ends here
