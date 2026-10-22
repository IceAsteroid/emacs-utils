;;; ia-window-utility.el --- Small snippets for window management  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

(defvar ia/other-window-mru-args '(nil 'dedicated 'not-selected 'no-other)
  "A list of arguments in the order that are passed to `get-mru-window' in `ia/other-window-mru'.")

(defun ia/other-window-mru ()
  "Cycle on most recently used live windows. Arguments refer to `get-mru-window’."
  (interactive)
  ;; Selecting windows with `select-window’ doesn’t trigger to run
  ;; `mouse-leave-buffer-hook’, unlike `other-window’, which is recorded by
  ;; "auto-select-window" feature that runs hooks like
  ;; `mouse-leave-buffer-hook’.
  (run-hooks 'mouse-leave-buffer-hook)
  (when-let ((mru-window (apply 'get-mru-window ia/other-window-mru-args)))
    (select-window mru-window nil)
    ;; Always return nil
    nil))


(provide 'ia-window-utility)

;;; ia-window-utility.el ends here
