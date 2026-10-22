;;; ia-fix-window-state-put-73627.el --- Fix window-state-put with side windows  -*- lexical-binding: t; -*-

;;; Commentary:
;; Workaround for an Emacs 31 regression: `window-state-put' cannot
;; restore a window state while the selected window is a dedicated
;; side window, because of a bug in the *fix* for Bug#73627.
;;
;; Background: Bug#73627 was about splitting a frame's root window
;; when the frame has side windows.  Its fix (commit a58dc58fec8d,
;; in Emacs 31) added a guard in `split-window' that, when the
;; window to split is the frame root and the frame has side windows,
;; redirects to splitting `window-main-window' instead.  That guard
;; assumes a main window always exists, which is not true while
;; restoring a window state (see below): with only a side window
;; left, `window-main-window' returns the root window itself -- the
;; side window -- and `split-window' recurses forever.
;;
;; Trigger: ECA displays its chat in a dedicated side window (see
;; `eca-chat--display-buffer').  When a command such as
;; `tab-previous'/'tab-next' switches tabs, `tab-bar-select-tab'
;; restores the target tab.  When the saved window configuration
;; (`wc') is not valid for the current frame (e.g. tabs restored
;; from a saved desktop via `desktop-save-mode', or tabs cloned
;; to another frame), it falls back to `(window-state-put ws nil
;; 'safe)'.  With `window' nil, `window-state-put' anchors the
;; restore on the *selected* window -- which is the ECA chat side
;; window.  It then deletes the other windows and tries to
;; `split-window' the side window, which, via the Bug#73627-fix
;; guard, re-splits `window-main-window' -- which is the side window
;; itself when it is the only window left -- causing infinite
;; recursion (`walk-window-tree-1: Lisp nesting exceeds
;; max-lisp-eval-depth').
;;
;; Note: this is a regression introduced by the Bug#73627 fix, not a
;; bug in the original report.  As of Emacs 31, no new bug number
;; has been filed for the recursion; the fix commit a58dc58fec8d is
;; the nearest upstream reference.
;;
;; The workaround: when `window-state-put' is asked to restore into
;; the selected window and that window is a dedicated side window,
;; temporarily select the frame's main window so the restore
;; anchors there instead.  The side window survives the restore.

;;; Code:

(defun ia-fix/window-state-put-73627--advice (orig-fn state &optional window ignore)
  "Call ORIG-FN with STATE, avoiding a side window as restore target.
WINDOW and IGNORE are passed through.  When WINDOW is nil and the
selected window is a dedicated side window (e.g. the ECA chat
window), redirect the restore to the frame's main window first."
  (if (and (null window)
           (window-parameter (selected-window) 'window-side))
      (let ((main (condition-case nil (window-main-window) (error nil))))
        (if (and main (window-live-p main) (not (eq main (selected-window))))
            (with-selected-window main
              (funcall orig-fn state nil ignore))
          (funcall orig-fn state nil ignore)))
    (funcall orig-fn state window ignore)))

(unless (advice-member-p #'ia-fix/window-state-put-73627--advice 'window-state-put)
  (advice-add 'window-state-put :around #'ia-fix/window-state-put-73627--advice))

(provide 'ia-fix-window-state-put-73627)
;;; ia-fix-window-state-put-73627.el ends here
