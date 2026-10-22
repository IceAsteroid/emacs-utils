;;; -*- lexical-binding: t; -*-
;; The ordering the installed entry gives, against the sources Emacs
;; consults: column-popup first, the entry second, the caller's ACTION
;; after it, and a named place left to the caller.
;; Run: make test
(require 'man)
(require 'ia-display-buffer-action)

(defvar nfail 0)
(defmacro check (label form)
  `(let ((val (condition-case err ,form (error (format "ERROR %S" err)))))
     (if (and val (not (stringp val)))
         (princ (format "ok   %s => %S\n" ,label val))
       (progn (setq nfail (1+ nfail))
              (princ (format "FAIL %s => %S\n" ,label val))))))

(defvar w1) (defvar w2)
(setq w1 (selected-window))
(setq w2 (split-window w1 nil 'below))

;;; ---- O1: a rule before the entry takes its buffer, the entry does not
;; column-popup's condition is stubbed for a buffer named *cp-popup*.
(defvar cp-hits 0)
(defun column-popup-display-control-p (buffer-name _alist)
  (string-match-p "\\*cp-popup\\*" buffer-name))
(defun column-popup--stub-display (buffer _alist)
  (setq cp-hits (1+ cp-hits))
  (set-window-buffer w2 buffer)
  w2)
(ia/display-buffer-action-mode +1)
;; the popup manager's mode enabled after ours: its entry is consed above
(push (cons 'column-popup-display-control-p '(column-popup--stub-display))
      display-buffer-alist)
(check "O1 the popup manager's entry is above the action's"
       (and (eq (caar display-buffer-alist) 'column-popup-display-control-p)
            (eq (car (nth 1 display-buffer-alist))
                'ia/display-buffer-action-control-p)))
(let ()
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (display-buffer (get-buffer-create "*cp-popup*"))
      (check "O1 a popup buffer goes to column-popup's rule" cp-hits)
      (check "O1 the entry's function never ran" (= calls 0))))
  ;; the same rule declines for other buffers, so the entry is reached
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (display-buffer (get-buffer-create "*not-a-popup*"))
      (check "O2 another buffer reaches the entry" (= cp-hits 1))))
  (ia/display-buffer-action-mode -1))

;;; ---- O3: the entry pre-empts a caller's ACTION
(defvar man-win (get-buffer-create "*man-win*"))
(with-current-buffer man-win (Man-mode))
(set-window-buffer w2 man-win)
(let ((noninteractive nil)
      (calls 0))
  (ia/display-buffer-action-mode +1)
  (cl-letf (((symbol-function 'aw-select)
             (lambda (&rest _) (setq calls (1+ calls)) w2)))
    (select-window w1)
    (let ((result (display-buffer (get-buffer-create "*man2*")
                                  '(display-buffer-reuse-mode-window
                                    (mode . Man-mode)))))
      (check "O3 the caller's ACTION is pre-empted by the entry"
             (and (eq result w1) (= calls 0)))
      (check "O3 the man window was not reused"
             (eq (window-buffer w2) man-win))))
  ;; a named place is left to the caller's ACTION
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (let ((win (display-buffer (get-buffer-create "*man3*")
                                 '((display-buffer-in-side-window)
                                   (side . bottom)))))
        (check "O4 a side request is left to the caller's ACTION"
               (and (= calls 0)
                    (eq (window-parameter win 'window-side) 'bottom))))))
  ;; ACTION t (the C-x 4 b shape) still asks
  (let ((calls 0)
        (ia/display-buffer-action-select 'auto))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (check "O5 ACTION t asks instead of using the selected window"
             (and (eq (display-buffer (get-buffer-create "*t5*") t) w2)
                  (= calls 1)))))
  ;; a pop-to-buffer caller selects the chosen window
  (let ((calls 0)
        (ia/display-buffer-action-select 'auto))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (let ((pop-up-windows t))
        (pop-to-buffer (get-buffer-create "*t6*") t))
      (check "O6 pop-to-buffer selects the chosen window"
             (eq (selected-window) w2))))
  (select-window w1)
  ;; the three select values: w1 must be unable to display for the choice
  ;; to run at all
  (set-window-dedicated-p w1 t)
  (let ((ia/display-buffer-action-select t))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (check "S t: the chosen window is selected"
             (progn (display-buffer (get-buffer-create "*s1*"))
                    (eq (selected-window) w2)))))
  (select-window w1)
  (let ((ia/display-buffer-action-select 'auto))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (check "S auto: the selection is unchanged"
             (progn (display-buffer (get-buffer-create "*s2*"))
                    (eq (selected-window) w1)))))
  (select-window w1)
  (let ((ia/display-buffer-action-select nil))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (let ((pop-up-windows t))
        (pop-to-buffer (get-buffer-create "*s3*") t))
      (check "S nil: the caller selected during the command"
             (eq (selected-window) w2))
      (run-hooks 'post-command-hook)
      (check "S nil: the selection returns at the end"
             (eq (selected-window) w1))))
  (set-window-dedicated-p w1 nil)
  (ia/display-buffer-action-mode -1))

(princ (if (zerop nfail) "\nALL PASSED\n"
         (format "\n%d CHECK(S) FAILED\n" nfail)))
(kill-emacs (if (zerop nfail) 0 1))
