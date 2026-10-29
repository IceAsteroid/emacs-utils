;;; emacs-utils.el --- Load-path helper for the utilities  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/emacs-utils
;; Version: 0.0.0
;; Package-Requires: ((emacs "31.1"))
;; Keywords: convenience, windows
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Add the repository's directories to `load-path'.  This file does not
;; load a library or enable a mode; require the library you need.  The
;; display action, the pivot, the window utility, the tab bar reader and
;; its optional consult library are in the `disbuf-pivot'
;; package; the `ia/other-window-mru' command and the consult
;; integration remain in `layout/'.  The other directories are
;; independent utilities.  See README.md.

;;; Code:

;; Compute the root directory dynamically at runtime or compile-time
(defvar ia/emacs-utils-sub-dirs
  '("core" ; core is the base library; the workaround files require it.
    "layout"
    "appearance"
    "buffer"
    "completion"
    "org"
    "info-inbox"
    "doc-lookup"
    "workaround")
  "List of subdirectories of this repository to add to `load-path'.")

;; Safely retrieve the root directory, protected against compilation.
(defvar ia/emacs-utils-root
  (file-name-directory
   (or load-file-name
       (bound-and-true-p byte-compile-current-file)
       buffer-file-name))
  "The root directory of the `emacs-utils' repository.")

(defun ia/emacs-utils-load-sub-dirs ()
  "Add the repository's subdirectories to `load-path'."
  (dolist (sub-dir ia/emacs-utils-sub-dirs)
    (let ((dir (expand-file-name sub-dir ia/emacs-utils-root)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

(provide 'emacs-utils)

;;; emacs-utils.el ends here
