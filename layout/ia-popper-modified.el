;;; ia-popper-modified.el --- Modified popper behavior for window management  -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: IceAsteroid
;; Keywords: outlines, org-mode, convenience

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; This package modifies the behavior of popper.el, a package that manages
;; windows for buffers that should display in a side window.
;;
;; The modification is on how a popper window is displayed: instead of a
;; bottom side window that overlaps all vertical windows (like the original
;; `popper-display-popup-at-bottom'), each popper window appears at the bottom
;; of the selected window's column.  When it is displayed from a side window
;; (e.g. Treemacs), the popper is anchored to a main-area window chosen per
;; `ia/popper-side-window-target'.
;;
;; `popper-toggle' is also given a three-state cycle (via an advice installed
;; at load time): a plain toggle opens a popper when none is open, selects an
;; open popper, and closes the popper when point is already inside it.  When
;; a popper is selected, the window that displays it is recorded in its
;; `quit-restore' parameter so that closing the popper returns to it.

(require 'popper)
(require 'cl-lib)
(require 'subr-x)
(require 'ia-window-prefix-pivot)

(declare-function aw-select "ace-window")

;;; Code:

(defvar ia/popper-auto-select-p nil)

(defvar ia/popper-window-height #'ia/popper--fit-window-height
  "Like the original `popper-window-height', for `ia/popper-modified-mode'.")

(defvar ia/popper-display-function 'ia/popper-select-at-column-bottom-window
  "Display function for popper buffers while `ia/popper-modified-mode' is on.
Analogous to `popper-display-function'.  The mode installs this value in
`display-buffer-alist'; when the mode is turned off, the original
`popper-display-function' is restored.")

(defun ia/popper--fit-window-height (win)
  "Fit the popup window WIN to its buffer, bounded by a quarter frame."
  (let ((quarter-height (floor (frame-height) 4)))
    (fit-window-to-buffer win quarter-height quarter-height)))

(defun ia/popper-window-p (win)
  "Test if a given window WIN is a popper window."
  (and (window-live-p win)
       (popper-display-control-p (window-buffer win))))

(defcustom ia/popper-side-window-target 'ace-window
  "Choose the anchor column for a popper displayed from a side window.
`ace-window' (default) prompts when the main area has several columns;
`mru' uses the most recently used editing window."
  :type '(choice (const :tag "Choose interactively with ace-window" ace-window)
                 (const :tag "Most recently used editing window" mru))
  :group 'popper)

(defun ia/popper--single-column-window ()
  "Return the bottom-most main-area window if the main area is one column.
Return nil when the layout is ambiguous or has no main-area window."
  (let* ((wins (seq-filter (lambda (w) (not (window-parameter w 'window-side)))
                           (window-list nil 'no-mini)))
         (columns (seq-uniq (mapcar #'window-left-column wins))))
    (and (= (length columns) 1)
         (car (seq-sort-by #'window-top-line #'> wins)))))

(defun ia/popper--side-window-target ()
  "Return a main-area window to anchor a popper, or nil.
Uses the single column if unambiguous, otherwise per
`ia/popper-side-window-target'; falls back to the most recently used
editing window."
  (let ((target (or (ia/popper--single-column-window)
                    (when (eq ia/popper-side-window-target 'ace-window)
                      (require 'ace-window)
                      (aw-select "Select window for popper: ")))))
    (if (and target
             (not (window-parameter target 'window-side))
             (not (window-minibuffer-p target)))
        target
      (ia/window-prefix-pivot--find-last-active-workspace))))

(defun ia/popper--windows-below (win)
  "Return the windows below WIN in its column, stopping before any side window."
  (let (windows)
    (while-let ((below (window-in-direction 'below win nil nil nil 'no-minibuf))
                ((not (window-parameter below 'window-side))))
      (push below windows)
      (setq win below))
    (nreverse windows)))

(defun ia/popper-display-at-column-bottom-window (buffer &optional alist)
  "Display popper BUFFER at the bottom of the selected window's column.
ALIST is the action alist given to the display function.  When the
selected window is a side window, anchor the popper below the window
chosen by `ia/popper-side-window-target' instead."
  (if (minibufferp)
      (with-selected-window (get-mru-window nil nil t)
        (ia/popper-display-at-column-bottom-window buffer alist))
    (let* ((current-win (selected-window))
           (bottom-win (car (last (ia/popper--windows-below current-win))))
           (height-alist (append alist
                                 `((window-height . ,ia/popper-window-height))))
           (popper-win
            (if (window-parameter current-win 'window-side)
                ;; A side window has no column: display in the main area,
                ;; reusing a window that already shows BUFFER (e.g. `gt'
                ;; re-displays its result) or the anchor from
                ;; `ia/popper--side-window-target'.
                (let ((anchor (or (when-let* ((existing (get-buffer-window buffer nil))
                                              ((not (window-parameter existing 'window-side))))
                                    existing)
                                  (ia/popper--side-window-target))))
                  (if anchor
                      (with-selected-window anchor
                        (ia/popper-display-at-column-bottom-window buffer alist))
                    (popper-display-popup-at-bottom buffer alist)))
              ;; Main area: reuse the current popper window, split below the
              ;; selected or bottom-most window, or reuse the bottom popper.
              (cond
               ((ia/popper-window-p current-win)
                (set-window-dedicated-p current-win nil)
                (display-buffer-same-window buffer alist))

               ((or (not bottom-win)
                    (not (ia/popper-window-p bottom-win)))
                (with-selected-window (or bottom-win current-win)
                  (display-buffer-below-selected buffer height-alist)))

               (t
                (set-window-dedicated-p bottom-win nil)
                (window--display-buffer buffer bottom-win alist))))))
      (when popper-win
        (set-window-parameter popper-win 'quit-restore
                              (list 'window 'window current-win
                                    (window-buffer popper-win)))
        (set-window-dedicated-p popper-win t))
      popper-win)))

(defun ia/popper-select-at-column-bottom-window (buffer &optional alist)
  "Display BUFFER and return its window.
ALIST is the action alist given to the display function.  Displays via
`ia/popper-display-at-column-bottom-window'; selects the resulting
window when `ia/popper-auto-select-p' is non-nil."
  (let ((window (ia/popper-display-at-column-bottom-window buffer alist)))
    (when (and window ia/popper-auto-select-p)
      (select-window window))
    window))

(defun ia-hook/popper-modified-purge-mode ()
  "Turn off `ia/popper-modified-mode' when `popper-mode' is disabled.
Also removes itself from `popper-mode-hook'."
  (unless popper-mode
    (ia/popper-modified-mode -1))
  (remove-hook 'popper-mode-hook 'ia-hook/popper-modified-purge-mode))

(define-minor-mode ia/popper-modified-mode
  "A global minor mode that modifies `popper-mode'."
  :group 'popper
  :global t
  (if popper-mode
      (progn
        (setf (alist-get 'popper-display-control-p display-buffer-alist)
              `(,(if ia/popper-modified-mode
                     ia/popper-display-function
                   popper-display-function)))
        (when ia/popper-modified-mode
          (add-hook 'popper-mode-hook 'ia-hook/popper-modified-purge-mode)))
    (when ia/popper-modified-mode
      (ia/popper-modified-mode -1)
      (message "Popper mode is not enabled. Turn it on before this mode."))))

(defun ia/popper--open-popper-window ()
  "Return a popper window to select, or nil if none is open.
Prefers the popper in the selected window's column, then the most
recently used popper window on the frame."
  (or
   ;; Popper below the selected window (its column).
   (cl-find-if #'ia/popper-window-p
               (ia/popper--windows-below (selected-window)))
   ;; Most recently used popper window anywhere on the frame.
   (let ((best nil) (best-time -1))
     (dolist (win (window-list nil 'no-mini))
       (when (and (not (window-parameter win 'window-side))
                  (ia/popper-window-p win)
                  (> (window-use-time win) best-time))
         (setq best-time (window-use-time win)
               best win)))
     best)))

(defun ia/popper--close-window-popper (win)
  "Close the popper displayed in window WIN.
Deleting the window makes `popper--update-popups' (via
`window-configuration-change-hook') move its buffer from
`popper-open-popup-alist' to `popper-buried-popup-alist'."
  (popper--delete-popup win))

(defun ia/popper--toggle-intercept-p (arg)
  "Return non-nil when a `popper-toggle' call with prefix ARG is intercepted.
Interception applies only to plain toggles while the column-bottom model
is active; prefix arguments 4 and 16 keep the original behavior."
  (and ia/popper-modified-mode
       (eq ia/popper-display-function
           'ia/popper-select-at-column-bottom-window)
       (not (or (equal arg 4) (equal arg 16)))))

(defun ia/popper-toggle-around (orig &optional arg)
  "Open, select, or close popper windows with `popper-toggle'.
ORIG is the original `popper-toggle'; ARG is the prefix argument.
A plain toggle opens a popper when none is open, selects an open
popper when point is in a regular window, and closes the popper
when point is already inside it.  Prefix arguments 4 and 16 keep
the original behavior."
  (cond
   ((not (ia/popper--toggle-intercept-p arg))
    (funcall orig arg))
   ((ia/popper-window-p (selected-window))
    ;; Inside a popper: close it.
    (ia/popper--close-window-popper (selected-window)))
   (t
    (if-let* ((popper (ia/popper--open-popper-window)))
        (progn
          ;; Record the window that displays the popper so closing
          ;; returns to it.
          (set-window-parameter
           popper 'quit-restore
           (list 'window 'window (selected-window)
                 (window-buffer popper)))
          (select-window popper))
      ;; No popper: open one.
      (funcall orig arg)))))

;; Install the advice at load time so reloading this file takes effect.
(advice-add 'popper-toggle :around #'ia/popper-toggle-around)

(provide 'ia-popper-modified)
;;; ia-popper-modified.el ends here
