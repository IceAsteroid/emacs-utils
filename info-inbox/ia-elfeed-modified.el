;;; ia-elfeed-modified.el --- Elfeed modifications and extra setup  -*- lexical-binding: t; -*-

;;; Commentary:
;; Custom UI and MPV integration behavior for Elfeed.

(require 'elfeed)
(require 'elfeed-tube)
(require 'elfeed-tube-mpv)

;;; Code:

(eval-and-compile
  (defvar ia/elfeed-modified-mode nil))

(defgroup ia/elfeed-modified nil
  "Customizations for the modified features of elfeed and elfeed-tube."
  :group 'elfeed
  :group 'elfeed-tube)

(defvar ia/ef-md--show-entry-switch-cache nil
  "Internal cache to restore `elfeed-show-entry-switch`.")

(defun ia/ef-md--apply-display-buffer-state (sym val)
  "Apply the state of SYM with VAL and update entry switch logic.
This is used as the `:set' function for customization of the
`ia/ef-md-show-entry-enable-display-buffer' user option."
  (set-default sym val)
  (if ia/elfeed-modified-mode
      (if val
          ;; Enable display-buffer delegation
          (progn
            (setq ia/ef-md--show-entry-switch-cache elfeed-show-entry-switch)
            (setq elfeed-show-entry-switch #'ia/ef-md-show-entry-display-buffer))
        ;; Disable display-buffer delegation (but keep mode on)
        (when (eq #'ia/ef-md-show-entry-display-buffer elfeed-show-entry-switch)
          (setq elfeed-show-entry-switch ia/ef-md--show-entry-switch-cache)))
    ;; If mode is off, just ensure we restore if needed
    (when (eq #'ia/ef-md-show-entry-display-buffer elfeed-show-entry-switch)
      (setq elfeed-show-entry-switch ia/ef-md--show-entry-switch-cache))))

(defcustom ia/ef-md-show-entry-enable-display-buffer nil
  "Non-nil to delegate elfeed entry buffer management to `display-buffer'."
  :type 'boolean
  :set #'ia/ef-md--apply-display-buffer-state
  :group 'ia/elfeed-modified)

(defun ia/ef-md-show-entry-display-buffer (buf &optional action norecord)
  "Show BUF using `pop-to-buffer', respecting `display-buffer-alist'."
  (pop-to-buffer buf action norecord))

(defun ia/elfeed-tube-mpv-advice (old-fun pos &optional arg)
  "Prompt to open in a new mpv instance.
This triggers unless a prefix argument ARG is supplied, or no MPV
instance is currently running."
  (unless (or arg (not (mpv-live-p)))
    (setq arg (yes-or-no-p "Open in a new mpv instance?")))
  (funcall old-fun pos arg))

;;;###autoload
(define-minor-mode ia/elfeed-modified-mode
  "Enable modified features of `elfeed' and `elfeed-tube'."
  :global t
  :group 'ia/elfeed-modified
  (if ia/elfeed-modified-mode
      (progn
        (ia/ef-md--apply-display-buffer-state 
         'ia/ef-md-show-entry-enable-display-buffer 
         ia/ef-md-show-entry-enable-display-buffer)
        (advice-add 'elfeed-tube-mpv :around #'ia/elfeed-tube-mpv-advice))
    (ia/ef-md--apply-display-buffer-state 'ia/ef-md-show-entry-enable-display-buffer nil)
    (advice-remove 'elfeed-tube-mpv #'ia/elfeed-tube-mpv-advice)))

(provide 'ia-elfeed-modified)

;;; ia-elfeed-modified.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("ia/ef-md-" . "ia/elfeed-modified-"))
;; End:
