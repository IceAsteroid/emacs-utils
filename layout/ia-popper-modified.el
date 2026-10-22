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

;; This package modifies the behavior of popper.el, which is a package that
;; manages windows, especially for buffers that should display in a side window.

;; The modification is mainly on how the popper window is displayed, by default,
;; popper windows are either managed individually via `display-buffer-alist' or
;; by popper that displays a side window that overlaps over vertical splitted
;; windows on root internal window of a frame, which is what I don't like, I
;; want each popper window appears only at the bottom of the selected winddow in
;; a vertical internal window, instead of overlapping over all vertical windows.

;;; TODO
;; Add threshold feature that open popper across horizontal windows if
;; the selected window is too small in width.

(require 'popper)
(require 'subr-x)

;;; Code:

(defvar ia/popper-auto-select-p nil)

(defvar ia/popper-window-height #'ia/popper--fit-window-height
  "Exactly like the original `popper-window-height', but for `popper-modified-mode'.")

(defvar ia/popper-display-function 'ia/popper-select-at-column-bottom-window
  "Works as `popper-display-function', but for `ia/popper-modified-mode'.

If user sets `popper-display-function' during `ia/popper-modified-mode'
is on, the user value will be perserved even the mode is turned off
later.")

(defun ia/popper--fit-window-height (win)
  "Determine the height of popup window WIN by fitting it to the buffer's content.
Fixed 25% min and max heights of the frame for popper windows."
  (let ((quarter-height (floor (frame-height) 4)))
    (fit-window-to-buffer win quarter-height quarter-height)))

(defun ia/popper-window-p (win)
  "Test if a given window WIN is a popper window."
  (and (window-live-p win)
       (popper-display-control-p (window-buffer win))))

(defun ia/popper-display-at-column-bottom-window (buffer &optional alist)
  "Always display popper-buffer at the column bottom window.

No matter spawned from a vertical upper selected window or not.

Unlike the original `popper-display-popup-at-bottom' which spawns as a
 bottom side window that hovering all other windows.

See BUFFER & ALIST in the original function."
  (if (minibufferp)
      (with-selected-window (get-mru-window)
        (ia/popper-display-at-column-bottom-window buffer alist))
    (let* ((current-win (selected-window))
           (win current-win)
           most-bottom-win
           switched-popper-win)

      ;; Efficiently find the bottom-most window without layout churn
      (while-let ((below (window-in-direction 'below win nil nil nil 'no-minibuf)))
        (setq most-bottom-win below)
        (setq win below))

      (if (window-parameter current-win 'window-side)
          (user-error "It is set to not display popper buffer for side windows."))

      ;; Direct assignment using structural cond instead of catch/throw blocks
      (setq switched-popper-win
            (cond
             ((ia/popper-window-p current-win)
              (set-window-dedicated-p current-win nil)
              (display-buffer-same-window buffer alist))

             ((not most-bottom-win)
              (display-buffer-below-selected
               buffer
               (append alist `((window-height . ,ia/popper-window-height)))))

             ((not (ia/popper-window-p most-bottom-win))
              (with-selected-window most-bottom-win
                (display-buffer-below-selected
                 buffer
                 (append alist `((window-height . ,ia/popper-window-height))))))

             (t
              (set-window-dedicated-p most-bottom-win nil)
              (window--display-buffer buffer most-bottom-win alist))))

      (when switched-popper-win
        (set-window-parameter switched-popper-win
                              'quit-restore
                              (list 'window 'window current-win (window-buffer switched-popper-win)))
        (set-window-dedicated-p switched-popper-win t))
      switched-popper-win)))

(defun ia/popper-select-at-column-bottom-window (buffer &optional alist)
  "Select the popup window after displaying it."
  (let ((window (ia/popper-display-at-column-bottom-window buffer alist)))
    (when (and window ia/popper-auto-select-p)
      (select-window window))))

(defun ia-hook/popper-modified-purge-mode ()
  (unless popper-mode
    (ia/popper-modified-mode -1))
  (remove-hook 'popper-mode-hook 'ia-hook/popper-modified-purge-mode))

(define-minor-mode ia/popper-modified-mode
  "A global minor mode that modifies `popper-mode'."
  :group 'popper
  :global t
  ;; No need to restore `display-buffer-alist', `popper-mode' would
  ;; remove the setting from it when the mode turns off.
  (if popper-mode
      (if ia/popper-modified-mode
          (progn (setf (alist-get 'popper-display-control-p display-buffer-alist)
                       `(,ia/popper-display-function))
                 ;; when popper-mode is turning off, turn this mode off as well.
                 (add-hook 'popper-mode-hook 'ia-hook/popper-modified-purge-mode))
        ;; Clean up and exit.
        (setf (alist-get 'popper-display-control-p display-buffer-alist)
              `(,popper-display-function)))
    (when ia/popper-modified-mode
      (ia/popper-modified-mode -1)
      (message "Popper mode is not enabled. Turn it on before this mode."))))

;;unfinished.
(defun ia/popper-toggle-override (&optional arg)
  "Override original `popper-toggle' behavior safely."
  (interactive "p")
  (let ((group (when popper-group-function (funcall popper-group-function))))
    (if popper-open-popup-alist
        (pcase arg
          (4 (popper-open-latest group))
          (16 (popper--bury-all))
          (_ (popper-close-latest)))
      (if (equal arg 16)
          (popper--open-all)
        (popper-open-latest group)))))



(provide 'ia-popper-modified)
;;; ia-popper-modified.el ends here
