;;; ia-window-prefix-pivot.el --- Pivot window prefix commands for special windows  -*- lexical-binding: t; -*-

;;; Commentary:
;; Opening a new buffer in a dedicated window with `same-window-prefix' doesn't
;; open it in the most recently used(mru), `other-window-prefix' does the
;; opposite with `same-window-prefix'.  The mode solve this problem.

(require 'cl-lib)
(require 'ia-window-utility)
(require 'ia-display-buffer-action)

;;; Code:

(defgroup ia-window-prefix-pivot nil
  "Pivot window prefix commands and better features."
  :group 'windows)

(defun ia/window-prefix-pivot--find-last-active-workspace ()
  "Return the most recently used normal editing workspace window on this frame.
Explicitly filters out active minibuffers and utility windows."
  (let ((frame-windows (window-list)))
    ;; Sort windows by their last interaction timestamp (newest first)
    (setq frame-windows (sort frame-windows
                              (lambda (w1 w2) 
                                (> (window-use-time w1) (window-use-time w2)))))
    ;; Iteratively scan for the first genuine text/code editing workspace
    (cl-find-if (lambda (w)
                  (not (or (window-minibuffer-p w)
                           (ia/window-cannot-display-p w))))
                frame-windows)))

(defun window-prefix-pivot-ad-display-buffer (orig-fun buffer &optional action)
  "Intercept `display-buffer' at the exact moment a window prefix executes.
If a prefix rule is armed and executing from a utility popup, dynamically
pivots focus to the true code workspace before the display logic runs."
  (if (and display-buffer-overriding-action
           (not (equal display-buffer-overriding-action '(nil . nil))) ; Ensure a prefix is actually armed
           (ia/window-cannot-display-p (selected-window)))
      (let ((target-workspace (ia/window-prefix-pivot--find-last-active-workspace)))
        (if target-workspace
            ;; Execute the core display layout engine as if standing in the main workspace
            (with-selected-window target-workspace
              (funcall orig-fun buffer action))
          (funcall orig-fun buffer action)))
    ;; Fall back to standard behavior if no prefix is live or we are in a normal window
    (funcall orig-fun buffer action)))

(defcustom ace-other-window-select t
  "Whether the window `aw-select' returns is selected.

`t' selects that window after the buffer is displayed, so the display
leaves point in the window the user chose.

`auto' selects nothing: the caller decides -- a caller that selects the
window it displayed (`pop-to-buffer') selects that window, and a caller
that does not select leaves the selected window alone.

`nil' selects nothing either, and undoes a caller that selects: at the
end of the command the window that was selected before the prompt is
selected again, the way `display-buffer' treats a `nil'
`post-command-select-window' entry."
  :type '(choice (const :tag "Always select" t)
                 (const :tag "Let the caller decide" auto)
                 (const :tag "Never select" nil))
  :group 'ia-window-prefix-pivot)

(defun ace-other-window-prefix ()
  "Display the buffer of the next command in an `ace-window` selected window.

You can bind this command to override `other-window-prefix' keybinding."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (let (window type)
       ;; If the current windows are less than the maximum amount, try
       ;; to pop up a new window, which also respects split
       ;; thresholds.  If it hits the limit, OR if popping up fails,
       ;; fall back to ace-window.
       (if (and (ia/window-split-p)
                (setq window (display-buffer-pop-up-window buffer alist)))
           (setq type 'window)
         (let ((choice (ia/choose-display-window aw-scope aw-ignore-current
                                                "Ace Window")))
           (if choice
               (progn
                 (setq window choice
                       type 'reuse)
                 (let ((answering (selected-window)))
                   (window--display-buffer buffer choice 'reuse alist)
                   (pcase ace-other-window-select
                     ('t (select-window choice))
                     ('nil (ia/select-window-post-command answering)))))
             (setq window nil))))
       (cons window type)))
     nil "[ace-other-window-prefix]")
  (message "Display next command buffer in a window via ace-window..."))

(defvar ia/other-tab-prefix--in-progress nil
  "Non-nil while `ia/other-tab-prefix' chooses the tab and its window.")

(defun ia/other-tab-prefix ()
  "Display the buffer of the next command in a tab.
The next buffer is the buffer displayed by the next command invoked
immediately after this command.  When the merged action alist names
`reusable-frames', a tab that already displays the buffer is used first;
otherwise read a tab name, where an empty name makes a new tab, and an
existing name selects that tab.  The buffer is then displayed there by
`ia/display-buffer-action-functions'.

A display made while the tab step runs -- `tab-bar-new-tab-choice' may
display a buffer of its own -- is left to the other display rules, so it
does not ask the tab question again."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (if ia/other-tab-prefix--in-progress
         (cons nil 'reuse)
       (let ((ia/other-tab-prefix--in-progress t))
         (let ((result (ia/display-buffer-action-tab buffer alist)))
           (cons (car-safe result) (or (cdr-safe result) 'reuse))))))
   nil "[other-tab]")
  (message "Display next command buffer in a tab..."))

;;;###autoload
(define-minor-mode ia/window-prefix-pivot-mode
  "Global minor mode to make window prefixes intuitive when used inside popups."
  :global t
  :group 'windows
  (if ia/window-prefix-pivot-mode
      (advice-add 'display-buffer :around #'window-prefix-pivot-ad-display-buffer)
    (advice-remove 'display-buffer #'window-prefix-pivot-ad-display-buffer)))

(provide 'ia-window-prefix-pivot)

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; window-prefix-pivot.el ends here
