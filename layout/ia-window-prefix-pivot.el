;;; ia-window-prefix-pivot.el --- Pivot window prefix commands for special windows  -*- lexical-binding: t; -*-

;;; Commentary:
;; Opening a new buffer in a dedicated window with `same-window-prefix' doesn't
;; open it in the most recently used(mru), `other-window-prefix' does the
;; opposite with `same-window-prefix'.  The mode solve this problem.

(require 'cl-lib)
(require 'ace-window)

;;; Code:

(defgroup ia-window-prefix-pivot nil
  "Pivot window prefix commands and better features."
  :group 'windows)

(defun ia/window-prefix-pivot--utility-window-p (window)
  "Return non-nil if WINDOW is a transient, side, or dedicated utility window.
Catches Popper popups, sidebar managers (e.g., Treemacs), and dedicated displays."
  (or (window-dedicated-p window)
      (window-parameter window 'window-side)
      (window-parameter window 'popper)))

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
                           (ia/window-prefix-pivot--utility-window-p w))))
                frame-windows)))

(defun window-prefix-pivot-ad-display-buffer (orig-fun buffer &optional action)
  "Intercept `display-buffer' at the exact moment a window prefix executes.
If a prefix rule is armed and executing from a utility popup, dynamically
pivots focus to the true code workspace before the display logic runs."
  (if (and display-buffer-overriding-action
           (not (equal display-buffer-overriding-action '(nil . nil))) ; Ensure a prefix is actually armed
           (ia/window-prefix-pivot--utility-window-p (selected-window)))
      (let ((target-workspace (ia/window-prefix-pivot--find-last-active-workspace)))
        (if target-workspace
            ;; Execute the core display layout engine as if standing in the main workspace
            (with-selected-window target-workspace
              (funcall orig-fun buffer action))
          (funcall orig-fun buffer action)))
    ;; Fall back to standard behavior if no prefix is live or we are in a normal window
    (funcall orig-fun buffer action)))

(defcustom ace-other-window-maximum 4
  "If windows are under this amount, display new buffer via pop-up.

Otherwise display the buffer in an existing window via `ace-window'.

This is to prevent opening too many windows when the screen is too large
that `split-width-threshold' and `split-height-threshold' determine to
split more windows popup windows."
  :group 'ia-window-prefix-pivot
  :type 'integer)

(defcustom ace-other-window-maximum-exclude-side t
  "Non-nil to exclude side windows for `ace-other-window-maximum'."
  :group 'ia-window-prefix-pivot
  :type 'boolean)

(defcustom ace-other-window-maximum-exclude-dedicated t
  "Non-nil to exclude dedicated windows for `ace-other-window-maximum'."
  :group 'ia-window-prefix-pivot
  :type 'boolean)

(defun ace-other-window-prefix ()
  "Display the buffer of the next command in an `ace-window` selected window."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (let* ((win-count (seq-count
                        (lambda (w)
                          ;; On demand to exclude side or dedicated
                          ;; windows for `ace-other-window-maximum'.
                          (and (not (and ace-other-window-maximum-exclude-side
                                         (window-parameter w 'window-side)))
                               (not (and ace-other-window-maximum-exclude-dedicated
                                         (window-dedicated-p w)))))
                        (aw-window-list)))
            window type)
       ;; If the current windows are less than the maximum amount, try
       ;; to pop up a new window, which also respects split
       ;; thresholds.  If it hits the limit, OR if popping up fails,
       ;; fall back to ace-window.
       (if (and (< win-count ace-other-window-maximum)
            (setq window (display-buffer-pop-up-window buffer alist)))
           (setq type 'window)
         (setq window (aw-select "Ace Window")
               type 'reuse)
         (window--display-buffer buffer window 'reuse alist))
       (cons window type)))
     nil "[ace-other-window-prefix]")
  (message "Display next command buffer in a window via ace-window..."))

;;;###autoload
(define-minor-mode ia/window-prefix-pivot-mode
  "Global minor mode to make window prefixes intuitive when used inside popups."
  :global t
  :group 'windows
  (if ia/window-prefix-pivot-mode
      (advice-add 'display-buffer :around #'window-prefix-pivot-ad-display-buffer)
    (advice-remove 'display-buffer #'window-prefix-pivot-ad-display-buffer)))

(provide 'ia-window-prefix-pivot)

;;; window-prefix-pivot.el ends here
