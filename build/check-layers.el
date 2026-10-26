;;; check-layers.el --- Check the library graph  -*- lexical-binding: t; -*-

;;; Commentary:
;; The `check-layers' target in the Makefile passes the files `FILES'
;; names in the environment.  This script reads the top-level `require'
;; and `provide' forms of those files and reports a library that
;; requires a file outside the library set, and libraries that require
;; each other in a cycle.  A file another file requires is a library.
;; See the library rule in TERM_AND_CONVENTION.md.

;;; Code:

(require 'cl-lib)

(defun check-layers--split (string)
  "Split STRING on whitespace, dropping empty fields."
  (split-string (or string "") "[ \t\n]+" t))

(defun check-layers--feature (form)
  "Return the feature named by the second element of FORM.
A `require' or `provide' form names the feature with a quoted symbol;
return that symbol, or nil when the form names no symbol."
  (let ((feature (nth 1 form)))
    (when (and (consp feature) (eq (car feature) 'quote))
      (setq feature (nth 1 feature)))
    (when (symbolp feature)
      feature)))

(defun check-layers--forms (file)
  "Return the top-level require and provide features of FILE.
The result is a list of two lists: the required features and the
provided features.  A `require' nested in another form, such as one in
`with-eval-after-load', is not a load-time require and is not read."
  (let (requires provides)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case err
          (while t
            (let ((form (read (current-buffer))))
              (when (consp form)
                (pcase (car form)
                  ('require
                   (let ((feature (check-layers--feature form)))
                     (when feature
                       (push feature requires))))
                  ('provide
                   (let ((feature (check-layers--feature form)))
                     (when feature
                       (push feature provides))))))))
        (end-of-file nil)
        (error (error "Cannot read %s: %s" file (error-message-string err)))))
    (list (nreverse requires) (nreverse provides))))

(defun check-layers ()
  "Check the library graph of the files `FILES' names.
`FILES' is read from the environment.  A file another file requires is
a library.  On a violation, print each one and exit with status 1;
otherwise print the libraries."
  (let* ((files (check-layers--split (getenv "FILES")))
         (features (make-hash-table :test 'eq))
         (requires-of (make-hash-table :test 'equal))
         (required nil)
         (errors nil))
    (dolist (file files)
      (if (file-exists-p file)
          (pcase-let ((`(,requires ,provides) (check-layers--forms file)))
            (puthash file requires requires-of)
            (dolist (feature provides)
              (puthash feature file features)))
        (push (format "FILES names a missing file: %s" file) errors)))
    (dolist (file files)
      (dolist (feature (gethash file requires-of))
        (let ((provider (gethash feature features)))
          (when (and provider (not (equal provider file)))
            (push provider required)))))
    (setq required (delete-dups required))
    (dolist (lib required)
      (dolist (feature (gethash lib requires-of))
        (let ((provider (gethash feature features)))
          (when (and provider (not (member provider required)))
            (push (format "%s requires %s, which is not a library"
                          lib provider)
                  errors)))))
    (let ((state (make-hash-table :test 'equal)))
      (cl-labels ((visit (file path)
                    (unless (eq (gethash file state) 'done)
                      (if (eq (gethash file state) 'visiting)
                          (push (format "The libraries require each other in a cycle: %s"
                                        (mapconcat #'identity
                                                   (reverse (cons file path))
                                                   " -> "))
                                errors)
                        (puthash file 'visiting state)
                        (dolist (feature (gethash file requires-of))
                          (let ((provider (gethash feature features)))
                            (when (and provider
                                       (member provider required))
                              (visit provider (cons file path)))))
                        (puthash file 'done state)))))
        (dolist (lib required)
          (visit lib nil))))
    (if errors
        (progn
          (dolist (problem (nreverse errors))
            (message "%s" problem))
          (kill-emacs 1))
      (message (ngettext "check-layers: %d library: %s"
                         "check-layers: %d libraries: %s"
                         (length required))
               (length required)
               (mapconcat #'identity required " ")))))

(check-layers)
