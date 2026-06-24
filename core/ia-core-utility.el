;;; ia-core-utility.el --- Core Features  -*- lexical-binding: t; -*-

;;; Commentary:
;; Core features that are used in this repo and my .emacs.d repo.

(defmacro ia/feat-chunk (name enable-p &rest body)
  "A wrapper to group related config by NAME. Executes BODY if ENABLED-P is non-nil"
  (declare (indent 2))
  (when (eval enable-p)
    `(progn ,@body)))

(eval-and-compile ;; For the function below in use with macros like use-package.
  (defvar ia/local-packages-dir nil)
  (defun ia/load-dir-recursive (dir &optional sub-dir-p arg force follow-symlinks)
    "Add DIR inside the parent dir `ia/local-packages-dir` to load-path and optionally compile.
Check ARG, FORCE and FOLLOW-SYMLINKS arguments in the docstring of `byte-recompile-directory`."
    (let ((default-directory (expand-file-name dir ia/local-packages-dir)))
      (funcall 'byte-recompile-directory default-directory arg force)
      (add-to-list 'load-path default-directory)
      ;; Handle subdirectories
      (when sub-dir-p (normal-top-level-add-subdirs-to-load-path))
      ;; Return for the caller.
      default-directory)))

(defun ia/package-install (pkg)
  "Install PKG if not installed, and load the package immediately."
  (unless (package-installed-p pkg)
    ;; Refresh archives if empty for fresh install, to prevent package not found.
    (unless package-archive-contents
      (package-refresh-contents))
    (package-install pkg))
  (require pkg))

(provide 'ia-core-utility)

;;; ia-core-utility.el ends here
