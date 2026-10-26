;;; ia-vundo-utility.el --- Additional features to vundo  -*- lexical-binding: t; -*-

;;; Commentary:
;; Vundo is a third-party package that can be found in ELPA.

(require 'vundo)

;;; Code:

(defun ia/undo-before-vundo ()
  (interactive)
  ;; when `undo' is invoked as code, it disregards
  ;; `buffer-read-only'. Force to block undo.
  (when buffer-read-only (signal 'text-read-only (list (current-buffer))))
  (undo)
  (vundo))
(keymap-set global-map "C-?" 'ia/undo-redo-before-vundo)

(defun ia/undo-redo-before-vundo ()
  (interactive)
  ;; when `undo' is invoked as code, it disregards
  ;; `buffer-read-only'. Force to block undo.
  (when buffer-read-only (signal 'text-read-only (list (current-buffer))))
  (undo-redo)
  (vundo))

(provide 'ia-vundo-utility)

;;; ia-vundo-utility.el ends here
