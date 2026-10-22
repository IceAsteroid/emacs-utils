;;; ia-persist-set-faces.el --- Features to set persistent faces  -*- lexical-binding: t; -*- 

;;; Commentary:
;; Features to set persistent faces regardless of theme switching.

;;; TODO
;; Refactor this code into a mode.

;;; Code:

(defvar ia/persist-set-faces--timer nil)

(defvar ia/persist-set-faces-debounce 0.005
  "Debounce to set the faces after a theme loads.
To prevent to set the faces before the theme finishes loading.")
(defvar ia/persist-set-faces--registry nil
  "List of functions to execute when a theme changes.")

(defun ia-timer/persist-set-faces--set (&rest _)
  "Debounce theme switches and execute all registered face overrides."
  (when (timerp ia/persist-set-faces--timer)
    (cancel-timer ia/persist-set-faces--timer))
  (setq ia/persist-set-faces--timer
        (run-with-timer
         ia/persist-set-faces-debounce nil
         (lambda ()
           (let ((inhibit-redisplay t))
             (mapc #'funcall ia/persist-set-faces--registry))))))
;; Set faces each time after a theme loads.
(advice-add 'enable-theme :after #'ia-timer/persist-set-faces--set)
;; For when switching back to the `default’ theme.
(advice-add 'disable-theme :after #'ia-timer/persist-set-faces--set)

(defmacro ia/theme-set-faces (&rest faces)
  "Define persistent face overrides. Works like `custom-set-faces'.
Can be called multiple times, handles quotes, and prevents registry bloat.

Each element in FACES should be of the form:
  '(FACE [KEYWORD VALUE]...)
Or:
  '(:eval BODY...)"
  (declare (indent 0))
  (let* ((unwrapped-faces
          (mapcar (lambda (f) (if (eq (car-safe f) 'quote) (cadr f) f)) faces))
         ;; Extract face names to create a unique, deterministic hash signature
         (face-identifiers (mapcar (lambda (f) (if (eq (car f) :eval) 'eval (car f))) unwrapped-faces))
         (hash-str (md5 (format "%S" face-identifiers)))
         (func-sym (intern (format "ia/theme-faces-gen-%s" (substring hash-str 0 8))))
         (body
          (mapcar
           (lambda (spec)
             (if (eq (car spec) :eval)
                 `(progn ,@(cdr spec))
               `(set-face-attribute ',(car spec) nil ,@(cdr spec))))
           unwrapped-faces)))
    `(progn
       ;; Function generated to be used in `ia-timer/persist-set-faces--set' when a theme loads.
       (defun ,func-sym ()
         ,(format "Automatically generated theme overrides for: %s" face-identifiers)
         ,@body)
       (add-to-list 'ia/persist-set-faces--registry ',func-sym)
       (,func-sym))))

(provide 'ia-persist-set-faces)

;;; ia-persist-set-faces.el ends here
