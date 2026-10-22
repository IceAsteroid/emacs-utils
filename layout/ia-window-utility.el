;;; ia-window-utility.el --- Small snippets for window management  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

(require 'ace-window)
(require 'cl-lib)

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
  (when-let* ((mru-window (apply 'get-mru-window ia/other-window-mru-args)))
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

(defcustom ia/window-split-maximum 4
  "The number of windows under which a split is preferred over asking.
When fewer windows than this can take a buffer's display, split a new
one with `display-buffer-pop-up-window'; at this number or more, ask
for a window with `ace-window' instead.  `ia/window-split-p' makes the
test."
  :group 'windows
  :type 'integer)

(defcustom ia/window-split-maximum-exclude-side t
  "Non-nil to leave side windows out of `ia/window-split-maximum'."
  :group 'windows
  :type 'boolean)

(defcustom ia/window-split-maximum-exclude-dedicated t
  "Non-nil to leave dedicated windows out of `ia/window-split-maximum'."
  :group 'windows
  :type 'boolean)

(defun ia/window-split-p ()
  "Return non-nil when a split is preferred over asking for a window.
Count the windows `aw-window-list' offers, leaving out the side windows
and dedicated windows that `ia/window-split-maximum-exclude-side' and
`ia/window-split-maximum-exclude-dedicated' exclude, and compare the
count with `ia/window-split-maximum'."
  (let ((count (cl-count-if
                (lambda (window)
                  (and (not (and ia/window-split-maximum-exclude-side
                                 (window-parameter window 'window-side)))
                       (not (and ia/window-split-maximum-exclude-dedicated
                                 (window-dedicated-p window)))))
                (aw-window-list))))
    (< count ia/window-split-maximum)))

(defun ia/choose-display-window (scope ignore-current &optional mode-line)
  "Ask for a window with `aw-select' to display a buffer in.
SCOPE and IGNORE-CURRENT are bound to `aw-scope' and
`aw-ignore-current' for the choice; MODE-LINE is passed to `aw-select'
and defaults to \"Display buffer in window\".

Ask again while the chosen window cannot display the buffer, a window
`ia/window-cannot-display-p' answers for.  Should the choice return the
window it was told to ignore -- `aw-select' has none other to offer --
choose nothing.

Return the chosen window, or `nil' when SCOPE is nil, in batch, while
the minibuffer is active, when the choice is cancelled, or when no
window was chosen.  Cancelling the choice (C-g) quits the command whose
display it is."
  (when (and scope
             (not noninteractive)
             (not (active-minibuffer-window)))
    (let ((aw-scope scope)
          (aw-ignore-current ignore-current)
          done win)
      (while (and (not done)
                  (setq win (aw-select (or mode-line
                                           "Display buffer in window")))
                  (window-live-p win))
        (cond
         ;; `aw-select' returns the window it was told to ignore when it
         ;; has none other to offer: its branch for one window returns
         ;; `(or (car wnd-list) start-window)' whatever
         ;; `aw-ignore-current' says.  Stop asking and choose nothing.
         ((and aw-ignore-current (eq win (selected-window)))
          (setq done t
                win nil))
         ((ia/window-cannot-display-p win))
         (t (setq done t))))
      win)))

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

;; Local Variables:
;; checkdoc-allow-quoting-nil-and-t: t
;; End:

;;; ia-window-utility.el ends here
