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

(defun ia/window-cannot-display-p (window)
  "Return non-nil if WINDOW does not take another buffer's display.
That is a window dedicated to its buffer, a side window, or a Popper
popup window."
  (or (window-dedicated-p window)
      (window-parameter window 'window-side)
      (window-parameter window 'popper)))

(defun ia/select-window-post-command (window)
  "Select WINDOW when the current command ends.
The entry that does it is added to `post-command-hook' and removes
itself when it runs, so no later command sees it.  This is the way
`display-buffer' treats a `nil' `post-command-select-window' entry."
  (when (window-live-p window)
    (letrec ((postfun
              (lambda ()
                (when (window-live-p window)
                  (select-window window))
                (remove-hook 'post-command-hook postfun))))
      (add-hook 'post-command-hook postfun))))


(provide 'ia-window-utility)

;;; ia-window-utility.el ends here
