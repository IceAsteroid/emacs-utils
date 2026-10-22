;;; ia-core-utility.el --- Core Features  -*- lexical-binding: t; -*-

;;; Commentary:
;; Core features that are used in this repo and my .emacs.d repo.

(defmacro ia/feat-chunk (name enable-p &rest body)
  "A wrapper to group related config by NAME. Executes BODY if ENABLED-P is non-nil"
  (declare (indent 2))
  (when (eval enable-p)
    `(progn ,@body)))

(eval-and-compile ;; For the function below in use with macros like use-package.
  (defvar-local ia/local-packages-dir nil
    "Local root directory for my custom Emacs packages.
This should be set per-file instead of global.  Used by
`ia/load-dir-recursive' and `ia/package-vc-install-local'.")
  (defun ia/load-dir--subdirs (root-dir)
    "Return ROOT-DIR and all non-hidden subdirectories inside it."
    (let ((dirs (list root-dir)))
      (dolist (file (directory-files root-dir t "^[^.]"))
        (when (file-directory-p file)
          (push file dirs)
          (setq dirs (append (ia/load-dir--subdirs file) dirs))))
      (delete-dups dirs)))
  (defun ia/load-dir-recursive (dir &optional sub-dir-p arg force follow-symlinks)
    "Add DIR inside the parent dir `ia/local-packages-dir` to load-path and optionally compile.
Check ARG, FORCE and FOLLOW-SYMLINKS arguments in the docstring of `byte-recompile-directory`."
    (let* ((default-directory (expand-file-name dir ia/local-packages-dir))
           ;; Follow autoload file standard naming conventions: 'pkgname-autoloads.el' or 'autoloads.el'
           (pkg-autoload (expand-file-name (format "%s-autoloads.el" dir) default-directory))
           (generic-autoload (expand-file-name "autoloads.el" default-directory)))
      (funcall 'byte-recompile-directory default-directory arg force)
      (add-to-list 'load-path default-directory)
      ;; Handle subdirectories
      (when sub-dir-p (normal-top-level-add-subdirs-to-load-path))
      ;; Load autoload files
      (cond
       ((file-exists-p pkg-autoload) (load pkg-autoload nil t))
       ((file-exists-p generic-autoload) (load generic-autoload nil t)))
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

(defun ia/package-vc-install (package &optional rev backend name)
  "Install PKG if not installed, and load the package immediately.
The ARGs are the same semantics of `package-vc-install's."
  (let* ((pkg-car package)
         ;; if package's a list and contains name, and the NAME arg is
         ;; also specified, choose the package's over NAME's.
         (name (or (and (symbolp pkg-car) pkg-car)
                   name)))
    (unless (package-installed-p name)
      ;; Refresh to ensure to find out dependencies.
      (unless package-archive-contents
        (package-refresh-contents))
      (package-vc-install package rev backend name))
    (require package)))

(defun ia/package-vc-install-local (package &optional dir)
  "Install local PACKAGE from checkout natively (Optimized for Emacs 30+).
Automatically injects :lisp-dir recipes for packages like pdf-tools."
  (let* ((pkg-sym (if (stringp package) (intern package) package))
         (pkg-str (symbol-name pkg-sym))
         (checkout-dir (if dir
                           (expand-file-name dir)
                         (expand-file-name pkg-str ia/local-packages-dir)))
         (lisp-dir (expand-file-name "lisp" checkout-dir)))
    (unless (package-installed-p pkg-sym)
      ;; 1. Refresh archives so it can find dependencies like tablist
      (unless package-archive-contents
        (package-refresh-contents))
      
      ;; 2. In Emacs 30, we can cleanly inject the lisp-dir spec into the global 
      ;; list, and package-vc-install-from-checkout will actually respect it!
      (when (file-directory-p lisp-dir)
        (add-to-list 'package-vc-selected-packages 
                     (list pkg-sym :lisp-dir "lisp")))
      ;; 3. Let the Emacs 30 native engine do the rest perfectly
      (package-vc-install-from-checkout checkout-dir pkg-str))
    (require pkg-sym)))

(provide 'ia-core-utility)

;;; ia-core-utility.el ends here
