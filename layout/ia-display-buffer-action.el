;;; ia-display-buffer-action.el --- Choose the window of a buffer the selected window cannot display  -*- lexical-binding: t; -*-

;;; Commentary:
;; When the selected window cannot display a buffer -- it is dedicated,
;; a side window, or a Popper popup -- the window the buffer goes to is
;; Emacs's choice, made by its default action functions, so the buffer
;; lands where the user does not expect it.  `ia/display-buffer-action-mode'
;; replaces that with one rule and one choice: a buffer is displayed in a
;; window that already displays it, else in the selected window, and a
;; buffer the selected window cannot display is displayed in a new window
;; when `ia/window-split-p' says a split is preferred, else in a window
;; the user chooses with `ace-window' -- choosing again while the chosen
;; window is one that cannot display it either.  A call that asks for a
;; tab or a frame is asked which one, or a new one, and the same rule then
;; displays the buffer there.
;;
;; The mode conses one `display-buffer-alist' entry at the front of the
;; list, matched by every buffer an earlier entry does not take.  Priority
;; is list order, and a package conses its entry at the front when its
;; mode is enabled, so enable a popup manager's mode after this one when
;; its rule is to take precedence for its buffers.  A request whose alist
;; names a place for the buffer -- a window, a direction, a side, a slot,
;; a tab or a frame -- is left to the caller's own action functions.

(require 'cl-lib)
(require 'tab-bar)
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
    ia/display-buffer-action-split-or-ask)
  "The action functions the mode's entry tries, in order.
Each is called with the buffer and the action alist, and the first one
that returns a window decides the display.  The default shows a buffer
in a window that already displays it, else in the selected window, and
otherwise splits a new window when `ia/window-split-p' says a split is
preferred, or asks for a window with `ace-window'.

An action function can be added, dropped or reordered here: putting
`display-buffer-same-window' first gives a buffer that another window
already displays a second window, and dropping
`ia/display-buffer-action-split-or-ask' removes the split and the
question.  A request whose alist names a place for the buffer -- a
window, a direction, a side, a slot, or a child frame -- is left to the
caller's own action functions before any function here is tried; a call
that asks for a tab or a frame is asked which one first, and the
functions here then display the buffer there."
  :type '(choice (function :tag "One action function")
                 (repeat :tag "Action functions" function))
  :group 'ia-display-buffer-action)

(defvar ia/display-buffer-action--action nil
  "The ACTION argument of the `display-buffer' call being decided.
The condition of the mode's entry records it, because `buffer-match-p'
passes the ACTION to the condition and the action functions receive only
the merged alist.")

(defun ia/display-buffer-action-control-p (_buffer action)
  "Match every buffer an earlier `display-buffer-alist' entry does not take.
This is the condition of the entry `ia/display-buffer-action-mode'
installs, so the mode's function is tried after column-popup's entry and
before the caller's ACTION argument, the special action,
`display-buffer-base-action' and the fallback action.  Record ACTION for
`ia/display-buffer-action--target'."
  (setq ia/display-buffer-action--action action)
  t)

(defun ia/display-buffer-action--functions (action)
  "Return the action functions ACTION names, as a list."
  (let ((functions (car-safe action)))
    (cond ((functionp functions) (list functions))
          ((listp functions) functions))))

(defun ia/display-buffer-action--target (alist)
  "Return `tab', `frame' or nil for the display ALIST and its ACTION.
A tab is asked for through `tab-name' or `tab-group', or through
`display-buffer-in-tab' or `display-buffer-in-new-tab' in the ACTION.  A
frame is asked for through `pop-up-frames', or through
`display-buffer-pop-up-frame' or `display-buffer-use-some-frame' in the
ACTION.  A child frame named by `parent-frame' is left to the caller."
  (let ((functions (ia/display-buffer-action--functions
                    ia/display-buffer-action--action)))
    (cond
     ((or (assq 'tab-name alist)
          (assq 'tab-group alist)
          (memq 'display-buffer-in-tab functions)
          (memq 'display-buffer-in-new-tab functions))
      'tab)
     ((or (assq 'pop-up-frames alist)
          (memq 'display-buffer-pop-up-frame functions)
          (memq 'display-buffer-use-some-frame functions))
      'frame))))

(defun ia/display-buffer-action--run (buffer alist)
  "Display BUFFER by the functions `ia/display-buffer-action-functions' lists.
ALIST is passed to each function.  Return the first window they display,
or nil."
  (let ((functions ia/display-buffer-action-functions))
    (unless (listp functions)
      (setq functions (list functions)))
    (cl-some (lambda (function) (funcall function buffer alist))
             functions)))

(defun ia/display-buffer-action--tab (buffer alist)
  "Display BUFFER in a tab by the mode's action functions.
The `tab-name' entry names the tab; a function there is called with
BUFFER and ALIST.  Without a name, read one, where an empty name makes a
new tab.  An existing name selects that tab; a new name makes a tab with
that name.  `tab-group' names the group of a new tab.  Return the window
the action functions display, or nil in batch or while the minibuffer is
active."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let* ((name (alist-get 'tab-name alist))
           (name (if (functionp name) (funcall name buffer alist) name))
           (name (or name
                     (completing-read
                      "Tab (empty for a new tab): "
                      (mapcar (lambda (tab) (alist-get 'name tab))
                              (tab-bar-tabs))
                      nil nil)))
           (index (and (not (string-empty-p name))
                       (cl-position name (tab-bar-tabs)
                                    :key (lambda (tab) (alist-get 'name tab))
                                    :test #'equal))))
      (if index
          (tab-bar-select-tab (1+ index))
        (tab-bar-new-tab)
        (unless (string-empty-p name)
          (tab-bar-rename-tab name))
        (let ((group (alist-get 'tab-group alist)))
          (when (functionp group)
            (setq group (funcall group buffer alist)))
          (when group
            (tab-bar-change-tab-group group))))
      (ia/display-buffer-action--run buffer alist))))

(defun ia/display-buffer-action--frames (alist)
  "Return the live visible frames a frame question can offer.
A `frame-predicate' entry in ALIST filters them, as it does for
`display-buffer-use-some-frame'."
  (let ((frames
         (cl-remove-if-not
          (lambda (frame)
            (and (frame-live-p frame)
                 (frame-visible-p frame)
                 (not (eq (frame-parameter frame 'minibuffer) 'only))))
          (frame-list)))
        (predicate (alist-get 'frame-predicate alist)))
    (if (functionp predicate)
        (cl-remove-if-not predicate frames)
      frames)))

(defun ia/display-buffer-action--frame (buffer alist)
  "Display BUFFER in a frame by the mode's action functions.
Read a frame title; an empty title makes a new frame through
`display-buffer-pop-up-frame', which keeps the `pop-up-frame-parameters'
of ALIST.  A title that names a frame selects that frame, then the action
functions display BUFFER in it, with the `inhibit-switch-frame' of ALIST
keeping the frame from being raised.  Return the window, or nil in batch
or while the minibuffer is active."
  (when (and (not noninteractive)
             (not (active-minibuffer-window)))
    (let* ((frames (ia/display-buffer-action--frames alist))
           (name (completing-read
                  "Frame (empty for a new frame): "
                  (delq nil (mapcar (lambda (frame)
                                      (frame-parameter frame 'name))
                                    frames))
                  nil nil))
           (frame (and (not (string-empty-p name))
                       (cl-find name frames
                                :key (lambda (frame)
                                       (frame-parameter frame 'name))
                                :test #'equal))))
      (if frame
          (progn
            (if (alist-get 'inhibit-switch-frame alist)
                (select-frame frame)
              (select-frame-set-input-focus frame))
            (ia/display-buffer-action--run buffer alist))
        (display-buffer-pop-up-frame buffer alist)))))

(defun ia/display-buffer-action--placed-p (alist)
  "Return non-nil if ALIST names a place for the buffer.
A window, a direction, a side, a slot, or a child frame named in ALIST is
a deliberate placement, left to the caller's own action functions.  A tab
or a frame that is not a child frame is asked about instead."
  (cl-some (lambda (key) (assq key alist))
           '(window direction side slot
             parent-frame child-frame-parameters)))

(defun ia/display-buffer-action-choose-window (buffer alist)
  "Display BUFFER in a window chosen with `ace-window'.
`ia/choose-display-window' asks for the window: it asks again while the
chosen window cannot display BUFFER, and chooses nothing when no window
can answer.  The chosen window displays BUFFER through
`window--display-buffer' with ALIST, so the caller's entries -- a
`body-function' among them -- still take effect.  What
`ia/display-buffer-action-select' does with the selected window is its
own choice: `t' selects the chosen window, `auto' selects nothing, and
`nil' selects nothing now and selects the answering window again at the
end of the command."
  (let* ((aw-scope (cl-case (cdr (assq 'reusable-frames alist))
                     ((nil) 'frame)
                     (visible 'visible)
                     ((0 t) 'global)))
         (aw-ignore-current (or (cdr (assq 'inhibit-same-window alist))
                                (ia/window-cannot-display-p (selected-window)))))
    (when-let* ((win (ia/choose-display-window aw-scope aw-ignore-current)))
      (let ((answering (selected-window)))
        (window--display-buffer buffer win 'reuse alist)
        (pcase ia/display-buffer-action-select
          ('t (select-window win))
          ('nil (ia/select-window-post-command answering))))
      win)))

(defun ia/display-buffer-action-split-or-ask (buffer alist)
  "Display BUFFER in a new window when a split is preferred, else ask.
`ia/window-split-p' decides through `ia/window-split-maximum' and its
two exclusion options.  When it says a split is preferred, try
`display-buffer-pop-up-window'; when that fails, and when the count is
not under the maximum, ask with `ia/display-buffer-action-choose-window'.
BUFFER and ALIST are passed to whichever of the two displays it."
  (or (and (ia/window-split-p)
           (display-buffer-pop-up-window buffer alist))
      (ia/display-buffer-action-choose-window buffer alist)))

(defun ia/display-buffer-action--display (buffer alist)
  "Display BUFFER by the mode's rule.
When the call asks for a tab or a frame, ask which one, or a new one, and
display BUFFER there by the action functions.  Otherwise, unless ALIST
names a place for the buffer, call the functions of
`ia/display-buffer-action-functions' in order and return the first window
they display."
  (pcase (ia/display-buffer-action--target alist)
    ('tab (ia/display-buffer-action--tab buffer alist))
    ('frame (ia/display-buffer-action--frame buffer alist))
    (_
     (unless (ia/display-buffer-action--placed-p alist)
       (ia/display-buffer-action--run buffer alist)))))

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
already displays it or in the selected window, then splits a new window
when `ia/window-split-p' says a split is preferred, and otherwise asks
for a window with `ace-window', by the action functions
`ia/display-buffer-action-functions' lists in order.  A call that asks
for a tab or a frame -- through `tab-name', `tab-group',
`pop-up-frames', or a tab or frame action function in its ACTION -- is
asked which one, or a new one, and the same functions display the buffer
there.  A request whose alist names a window, a direction, a side, a
slot, or a child frame is left to the caller's own action functions, and
`display-buffer-overriding-action' is consulted before the entry.
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
