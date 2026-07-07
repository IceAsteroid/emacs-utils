;;; emacs-utils.el --- Entry Point  -*- lexical-binding: t; -*-

;; Author: IceAstroid
;; Homepage: https://github.com/IceAsteroid/emacs-utils

;;; Commentary:
;; 

;;; Code:

;; Compute the root directory dynamically at runtime or compile-time
(defvar ia/emacs-utils-sub-dirs
  '("core" ;core must be loaded, it's a dependency used in other subdirs.
    "layout"
    "appearance"
    "buffer"
    "completion"
    "org"
    "info-inbox"
    "doc-lookup"
    "workaround")
  "List of subdirectories of this repo to add their paths to `load-path'.")

;; Safely retrieve the root directory, protected against compilation.
(defvar ia-utils-root
  (file-name-directory
   (or load-file-name
       (bound-and-true-p byte-compile-current-file)
       buffer-file-name))
  "The root directory of the `emacs-utils' repository.")

(defun ia-load-sub-dirs ()
  "Inject sub directories into the `load-path'."
 (dolist (sub-dir ia/emacs-utils-sub-dirs)
  (let ((dir (expand-file-name sub-dir ia-utils-root)))
    (when (file-directory-p dir)
      (add-to-list 'load-path dir)))))

(provide 'emacs-utils)

;;; emacs-utils.el ends here
