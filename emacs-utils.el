;;; emacs-utils.el --- Entry Point  -*- lexical-binding: t; -*-

;; Author: IceAstroid
;; Homepage: https://github.com/IceAsteroid/emacs-utils

;;; Commentary:
;; 

;;; Code:

(defvar ia/emacs-utils-sub-dirs
  '("core"
    "layout"
    "appearance"
    "buffer"
    "completion"
    "org"
    "info-inbox"
    "doc-lookup"
    "workaround")
  "List of subdirectories of this repo to add their paths to `load-path'.")

;; Compute the root directory dynamically at runtime or compile-time
(eval-and-compile
  (defvar ia-utils-root (file-name-directory (or load-file-name buffer-file-name))
    "The root directory of the emacs-utils repository."))

;; Automatically inject sub directories into the load-path
(eval-and-compile
  (dolist (sub-dir ia/emacs-utils-sub-dirs)
    (let ((dir (expand-file-name sub-dir ia-utils-root)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

;; Load foundational features used in other sub directories.
(require 'ia-core-utility)

(provide 'emacs-utils)

;;; emacs-utils.el ends here
