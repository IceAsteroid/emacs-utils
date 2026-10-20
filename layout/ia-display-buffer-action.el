;;; ia-display-buffer-action.el --- Choose the window of a buffer the selected window cannot display  -*- lexical-binding: t; -*-

;;; Commentary:
;; When the selected window cannot display a buffer -- it is dedicated,
;; a side window, or a Popper popup -- the window the buffer goes to is
;; Emacs's choice, made by its default action functions, so the buffer
;; lands where the user does not expect it.  `ia/display-buffer-action-mode'
;; replaces that with one rule and one choice: a buffer is displayed in a
;; window that already displays it, else in the selected window,
;; and a buffer the selected window cannot display is displayed in a
;; window the user chooses with `ace-window' -- choosing again while the
;; chosen window is one that cannot display it either.
;;
;; The mode conses one `display-buffer-alist' entry at the front of the
;; list, matched by every buffer an earlier entry does not take.  Priority
;; is list order, and a package conses its entry at the front when its
;; mode is enabled, so enable a popup manager's mode after this one when
;; its rule is to take precedence for its buffers.  A request whose alist
;; names a place for the buffer -- a window, a direction, a side, a slot,
;; a tab or a frame -- is left to the caller's own action functions.

(require 'cl-lib)
(require 'ace-window)
(require 'ia-window-utility)

;;; Code:

(defgroup ia-display-buffer-action nil
  "Choose the window of a buffer the selected window cannot display."
  :group 'windows
  :prefix "ia-display-buffer-action-")

(defcustom ia/display-buffer-action-select t
  "Whether the action selects the window you chose.

`t' selects the chosen window after displaying the buffer, so the choice
always lands point where you pointed.

`auto' selects nothing: the caller decides -- `pop-to-buffer' selects
the window it displays, and a caller that does not select leaves the
selection alone.

`nil' selects nothing either, and undoes a caller that selects: at the
end of the command the window that was selected when the action ran is
selected again, the way `display-buffer' treats a `nil'
`post-command-select-window' entry."
  :type '(choice (const :tag "Always select" t)
                 (const :tag "Let the caller decide" auto)
                 (const :tag "Never select" nil))
  :group 'ia-display-buffer-action)

(defcustom ia/display-buffer-action-functions
  '(display-buffer-reuse-window
    display-buffer-same-window
    ia/display-buffer-action-choose-window)
  "The action functions the mode's entry tries, in order.
Each is called with the buffer and the action alist, and the first one
that returns a window decides the display.  The default shows a buffer
in a window that already displays it, else in the selected window, and
otherwise asks for a window with `ace-window'.

An action function can be added, dropped or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`ia/display-buffer-action-choose-window' removes the question.  A request
whose alist names a place for the buffer is left to the caller's own
action functions before any function here is tried."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'ia-display-buffer-action)

(defun ia/display-buffer-action-control-p (_buffer _alist)
  "Match every buffer an earlier `display-buffer-alist' entry does not take.
This is the condition of the entry `ia/display-buffer-action-mode'
installs, so the mode's function is tried after column-popup's entry and
before the caller's ACTION argument, the special action,
`display-buffer-base-action' and the fallback action."
  t)

(defun ia/display-buffer-action--placed-p (alist)
  "Return non-nil if ALIST names a place for the buffer.
A window, a direction, a side, a slot, a tab or a frame named in ALIST is
a deliberate placement, left to the caller's own action functions."
  (cl-some (lambda (key) (assq key alist))
           '(window direction side slot tab-name tab-group
             parent-frame child-frame-parameters pop-up-frames)))

(defun ia/display-buffer-action-choose-window (buffer alist)
  "Display BUFFER in a window chosen with `ace-window'.

The chosen window displays BUFFER through `window--display-buffer' with
ALIST, so the caller's entries -- a `body-function' among them -- still
take effect.

Choose again while the chosen window cannot display BUFFER: a window
`ia/window-cannot-display-p' accepts (dedicated, a side window, or a
Popper popup).  The window that just refused the display, the selected
window, is not offered, nor is it when the caller asked for another
window through `inhibit-same-window'.  Should the choice return that
window anyway -- `aw-select' has none other to offer -- choose nothing,
so the action functions that follow can display the buffer where the
caller asked.

Choose nothing when no one can answer: in batch, or while the minibuffer
is active, where the displays are the minibuffer's own helpers and a
choice would steal the completion keys.  Return `nil' then, so the
action functions that follow run.  Cancelling the choice (C-g) quits the
command whose display it is.  What `ia/display-buffer-action-select'
does with the selected window is its own choice: `t' selects the chosen
window, `auto' selects nothing, and `nil' selects nothing now and
selects the answering window again at the end of the command."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let* ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                       ((nil) 'frame)
                       (visible 'visible)
                       ((0 t) 'global)))
           (aw-ignore-current (or (cdr (assq 'inhibit-same-window alist))
                                  (ia/window-cannot-display-p (selected-window))))
           done win)
      (when aw-scope
        (while (and (not done)
                    (setq win (aw-select "Display buffer in window"))
                    (window-live-p win))
          (cond
           ;; `aw-select' returns the window it was told to ignore when it
           ;; has none other to offer: its branch for one window returns
           ;; `(or (car wnd-list) start-window)' whatever
           ;; `aw-ignore-current' says.  Stop asking and decline.
           ((and aw-ignore-current (eq win (selected-window)))
            (setq done t
                  win nil))
           ((ia/window-cannot-display-p win))
           (t (setq done t))))
        (when (and win (window-live-p win))
          (let ((answering (selected-window)))
            (window--display-buffer buffer win 'reuse alist)
            (pcase ia/display-buffer-action-select
              ('t (select-window win))
              ('nil (ia/select-window-post-command answering))))
          win)))))

(defun ia/display-buffer-action--display (buffer alist)
  "Display BUFFER by the mode's rule, unless ALIST names a place for it.
ALIST is the action alist of the `display-buffer' call.  Decline
\(return nil) when it names a window, a direction, a side, a slot, a tab
or a frame, so the caller's own action functions decide; otherwise call
the functions of `ia/display-buffer-action-functions' in order and return
the first window they display."
  (unless (ia/display-buffer-action--placed-p alist)
    (let ((functions ia/display-buffer-action-functions))
      (unless (listp functions)
        (setq functions (list functions)))
      (cl-some (lambda (function) (funcall function buffer alist))
               functions))))

(defun ia/display-buffer-action--rule ()
  "Return the entry `ia/display-buffer-action-mode' installs."
  (cons 'ia/display-buffer-action-control-p
        '(ia/display-buffer-action--display)))

(defun ia/display-buffer-action--install ()
  "Cons the mode's entry at the front of `display-buffer-alist'.
An entry `ia/display-buffer-action-control-p' already present is
replaced, so enabling an enabled mode leaves one entry."
  (setq display-buffer-alist
        (cons (ia/display-buffer-action--rule)
              (cl-remove 'ia/display-buffer-action-control-p
                         display-buffer-alist :key 'car))))

(defun ia/display-buffer-action--uninstall ()
  "Remove the mode's entry, and nothing else."
  (setq display-buffer-alist
        (cl-remove 'ia/display-buffer-action-control-p
                   display-buffer-alist :key 'car)))

;;;###autoload
(define-minor-mode ia/display-buffer-action-mode
  "Choose the window of a buffer the selected window cannot display.
When enabled, cons a `display-buffer-alist' entry at the front of the
list, matching every buffer an earlier entry does not take.  Priority is
list order: a popup manager's rule takes precedence for its buffers when
that manager's mode is enabled after this one, since its entry is then
consed above.  The entry's function displays a buffer in a window that
already displays it or in the selected window, and in a window chosen
with `ace-window' when neither can take it, by the action functions
`ia/display-buffer-action-functions' lists in order.  A request whose
alist names a place for the buffer -- a window, a direction, a side, a
slot, a tab or a frame -- is left to the caller's own action functions,
and `display-buffer-overriding-action' is consulted before the entry.
When disabled, remove that entry."
  :global t
  :group 'ia-display-buffer-action
  (if ia/display-buffer-action-mode
      (ia/display-buffer-action--install)
    (ia/display-buffer-action--uninstall)))

(provide 'ia-display-buffer-action)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; ia-display-buffer-action.el ends here
