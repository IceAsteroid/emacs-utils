;;; ia-window-utility.el --- Cycle on the most recently used window  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/emacs-utils
;; Package-Requires: ((ace-window "0"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The most recently used window command.  The window test, the split
;; options and the window prompt are in the `display-buffer-pivot'
;; package.

;;; Code:

(require 'ace-window)

(defvar ia/other-window-mru-args '(nil 'dedicated 'not-selected 'no-other)
  "The arguments `ia/other-window-mru' passes to `get-mru-window', in order.")

(defun ia/other-window-mru ()
  "Cycle on most recently used live windows.  Arguments refer to `get-mru-window’."
  (interactive)
  ;; Selecting windows with `select-window’ doesn’t trigger to run
  ;; `mouse-leave-buffer-hook’, unlike `other-window’, which is recorded by
  ;; "auto-select-window" feature that runs hooks like
  ;; `mouse-leave-buffer-hook’.
  (run-hooks 'mouse-leave-buffer-hook)
  (when-let* ((mru-window (apply 'get-mru-window ia/other-window-mru-args)))
    (select-window mru-window nil)
    ;; Always return nil
    nil))

(provide 'ia-window-utility)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; ia-window-utility.el ends here
