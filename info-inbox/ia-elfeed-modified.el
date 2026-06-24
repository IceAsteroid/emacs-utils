;;; ia-elfeed-modified.el --- Elfeed modifications and extra setup  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

(require 'elfeed)
(require 'elfeed-tube)
(require 'elfeed-tube-mpv)

;;; Code:

(defgroup ia/elfeed-modified nil
  "Customizations for the modified features of elfeed and elfeed-tube."
  :group 'elfeed
  :group 'elfeed-tube)

(defun ia/elfeed-tube-mpv-advice (old-fun pos &optional arg)
  "Always ask user to open in a new mpv instance or not.
Instead of where only press c-u prefix to open in a new instance."
  (unless arg
    (setq arg (yes-or-no-p "Open in a new mpv instance?")))
  (funcall old-fun (point) arg))

(define-minor-mode ia-elfeed-modified-mode
  "Enable modified features of `elfeed' and `elfeed-tube'."
  :global t
  :group 'ia/elfeed-modified
  (if ia-elfeed-modified-mode
      (advice-add 'elfeed-tube-mpv :around 'ia/elfeed-tube-mpv-advice)
    (advice-remove 'elfeed-tube-mpv 'ia/elfeed-tube-mpv-advice)))

(provide 'ia-elfeed-modified)

;;; ia-elfeed-modified.el ends here
