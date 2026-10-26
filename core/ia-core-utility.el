;;; ia-core-utility.el --- Core features  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/emacs-utils
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Core features used by this repository and by a user's configuration.
;; A file that uses `ia/feat-chunk' requires this library.

;;; Code:

(require 'package)
(require 'package-vc)

(defmacro ia/feat-chunk (name enable-p &rest body)
  "Evaluate BODY when ENABLE-P is non-nil.
NAME labels the group for a reader; it is not evaluated.  ENABLE-P is
evaluated when the form runs, so a byte-compiled file tests the Emacs
that loads it, not the Emacs that compiled it."
  (declare (indent 2))
  (ignore name)
  `(when ,enable-p
     ,@body))

(eval-and-compile ;; For the function below in use with macros like use-package.
  (defvar-local ia/local-packages-dir nil
    "Local root directory for custom Emacs packages.
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
    "Add DIR under `ia/local-packages-dir' to `load-path' and compile it.
SUB-DIR-P non-nil adds the subdirectories of DIR.  ARG, FORCE and
FOLLOW-SYMLINKS are passed to `byte-recompile-directory'."
    (let* ((default-directory (expand-file-name dir ia/local-packages-dir))
           ;; Follow autoload file standard naming conventions: 'pkgname-autoloads.el' or 'autoloads.el'
           (pkg-autoload (expand-file-name (format "%s-autoloads.el" dir) default-directory))
           (generic-autoload (expand-file-name "autoloads.el" default-directory)))
      (funcall 'byte-recompile-directory default-directory arg force follow-symlinks)
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
  "Install PACKAGE if not installed, and load it immediately.
REV, BACKEND and NAME have the same meaning as in
`package-vc-install'."
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
  "Install local PACKAGE from checkout DIR, or from `ia/local-packages-dir'.
DIR defaults to the PACKAGE name under `ia/local-packages-dir'.  A
checkout with a Lisp directory gets a `:lisp-dir' recipe, as pdf-tools
does."
  (let* ((pkg-sym (if (stringp package) (intern package) package))
         (pkg-str (symbol-name pkg-sym))
         (checkout-dir
          (if dir
              (expand-file-name dir)
            (expand-file-name
             pkg-str
             ;; Explicitly bail out user-error if
             ;; `ia/local-packages-dir' is nil and DIR is not
             ;; specified.  to prevent implicitly to fallback to
             ;; `default-directory' when expanding the path with
             ;; `expand-file-name'.
             (or ia/local-packages-dir
                 (user-error "Cannot install local package: `ia/local-packages-dir' is nil")))))
         (lisp-dir (expand-file-name "lisp" checkout-dir)))
    ;; Guard to check the path validation of `checkout-dir', before
    ;; feeding to `package-vc-install-from-checkout' that creates
    ;; dangling symlink if invalid.
    (unless (file-directory-p checkout-dir)
      (user-error "Cannot install local package: checkout directory %S does not exist"
                  checkout-dir))
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

(defun ia/ensure-substring (string substring &optional separator prepend regexp-p)
  "Ensure literal SUBSTRING is in STRING and return the resulting string.

SEPARATOR is a character or a string to insert between SUBSTRING and
STRING in the returned string.  PREPEND non-nil puts SUBSTRING before
STRING; otherwise SUBSTRING follows it.  REGEXP-P non-nil treats
SUBSTRING as a regexp.

This does not prevent a partial match such as `mac' matching `emacs';
use `ia/ensure-substring-item' instead."
  (let ((pattern (if regexp-p
                     substring
                   ;; Treat SUBSTRING as a literal by default.
                   (regexp-quote substring))))
    (if (string-match-p pattern string)
        string
      (if prepend
          (concat substring separator string)
        (concat string separator substring)))))

(defun ia/ensure-substring-item (string item separator &optional prepend)
  "Ensure ITEM is in the separated STRING without partial matches.
SEPARATOR separates the items.  PREPEND non-nil puts ITEM before the
other items; otherwise ITEM follows them.  A partial match such as
`mac' matching `emacs' is not a match."
  (let ((items (split-string string separator)))
    (if (member item items)
        string ;; The exact item is already in the list
      ;; Otherwise, add it and rejoin the string
      (let ((new-items (if prepend
                           (cons item items)
                         (append items (list item)))))
        ;; mapconcat takes: (FUNCTION SEQUENCE SEPARATOR)
        (mapconcat #'identity new-items separator)))))

(provide 'ia-core-utility)

;;; ia-core-utility.el ends here
