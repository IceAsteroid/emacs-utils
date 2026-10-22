;;; -*- lexical-binding: t; -*-
;; Behavioural checks for ia/display-buffer-action-mode and the re-ask
;; loop in ace-other-window-prefix.  Run: make test
(require 'ia-display-buffer-action)
(require 'ia-window-prefix-pivot)
(require 'buttercup)

(defvar nfail 0)
(defmacro check (label form)
  `(let ((val (condition-case err ,form (error (format "ERROR %S" err)))))
     (if (and val (not (stringp val)))
         (princ (format "ok   %s => %S\n" ,label val))
       (progn (setq nfail (1+ nfail))
              (princ (format "FAIL %s => %S\n" ,label val))))))

(defun ia/display-ask-checks ()
  (setq nfail 0)

;;; ---- the entry, the mode's install and its removal
(check "mode off: no entry"
       (null (assq 'ia/display-buffer-action-control-p display-buffer-alist)))
(ia/display-buffer-action-mode +1)
(check "mode on: the entry is first when column-popup's is absent"
       (eq (caar display-buffer-alist)
           'ia/display-buffer-action-control-p))
(check "mode on: `display-buffer-base-action' is untouched"
       (equal display-buffer-base-action '(nil . nil)))
(ia/display-buffer-action-mode -1)
(check "mode off: the entry is removed"
       (null (assq 'ia/display-buffer-action-control-p display-buffer-alist)))
(check "mode off: `display-buffer-base-action' is still untouched"
       (equal display-buffer-base-action '(nil . nil)))

;; enabling twice leaves one entry; disabling twice removes it once
(ia/display-buffer-action-mode +1)
(ia/display-buffer-action-mode +1)
(check "enable twice: one entry"
       (= 1 (length (cl-remove-if-not
                     (lambda (e) (eq (car e) 'ia/display-buffer-action-control-p))
                     display-buffer-alist))))
(ia/display-buffer-action-mode -1)
(ia/display-buffer-action-mode -1)
(check "disable twice: no entry"
       (null (assq 'ia/display-buffer-action-control-p display-buffer-alist)))

;; the entry is consed at the front, above another package's entry
(let ((display-buffer-alist
       (list (cons 'column-popup-display-control-p '((ignore))))))
  (ia/display-buffer-action-mode +1)
  (check "the entry is consed at the front"
         (and (eq (caar display-buffer-alist)
                  'ia/display-buffer-action-control-p)
              (eq (car (nth 1 display-buffer-alist))
                  'column-popup-display-control-p)))
  (ia/display-buffer-action-mode -1)
  (check "disabling leaves the other entry alone"
         (and (= 1 (length display-buffer-alist))
              (eq (caar display-buffer-alist)
                  'column-popup-display-control-p))))
(ia/display-buffer-action-mode +1)

;;; ---- layout: w1 above w2
(defvar w1) (defvar w2)
(setq w1 (selected-window))
(setq w2 (split-window w1 nil 'below))

;;; ---- the split rule: under the maximum, split before asking
(let ((windows (list w1 w2)))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows)))
    (let ((ia/window-split-maximum 3))
      (check "split: two windows are under a maximum of three"
             (ia/window-split-p)))
    (let ((ia/window-split-maximum 2))
      (check "split: two windows are not under a maximum of two"
             (not (ia/window-split-p))))
    (set-window-dedicated-p w2 t)
    (let ((ia/window-split-maximum 2)
          (ia/window-split-maximum-exclude-dedicated t))
      (check "split: a dedicated window is left out"
             (ia/window-split-p)))
    (let ((ia/window-split-maximum 2)
          (ia/window-split-maximum-exclude-dedicated nil))
      (check "split: a dedicated window is counted when not excluded"
             (not (ia/window-split-p))))
    (set-window-dedicated-p w2 nil)))
(let ((side (display-buffer-in-side-window (get-buffer-create "*ia-side-free*")
                                           '((side . right))))
      (windows nil))
  (setq windows (list w1 side))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows)))
    (let ((ia/window-split-maximum 2)
          (ia/window-split-maximum-exclude-side t))
      (check "split: a side window is left out"
             (ia/window-split-p)))
    (let ((ia/window-split-maximum 2)
          (ia/window-split-maximum-exclude-side nil)
          (ia/window-split-maximum-exclude-dedicated nil))
      (check "split: a side window is counted when not excluded"
             (not (ia/window-split-p)))))
  (delete-window side))

;;; ---- the action function splits under the maximum, asks at it
(let ((noninteractive nil)
      (ia/display-buffer-action-select 'auto)
      (split-calls 0)
      (ask-calls 0)
      (windows (list w1 w2)))
  (cl-letf (((symbol-function 'aw-window-list) (lambda () windows))
            ((symbol-function 'display-buffer-pop-up-window)
             (lambda (_buffer _alist) (setq split-calls (1+ split-calls)) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w2)))
    (let ((ia/window-split-maximum 4))
      (check "split-or-ask: under the maximum, the split decides"
             (and (eq (ia/display-buffer-action-split-or-ask
                       (get-buffer-create "*ia-split*") nil)
                      w2)
                  (= split-calls 1)
                  (= ask-calls 0))))
    (setq split-calls 0)
    (let ((ia/window-split-maximum 2))
      (check "split-or-ask: at the maximum, the question decides"
             (and (eq (ia/display-buffer-action-split-or-ask
                       (get-buffer-create "*ia-split2*") nil)
                      w2)
                  (= split-calls 0)
                  (= ask-calls 1))))
    (setq split-calls 0
          ask-calls 0)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil)))
      (let ((ia/window-split-maximum 4))
        (check "split-or-ask: a failed split asks"
               (and (eq (ia/display-buffer-action-split-or-ask
                         (get-buffer-create "*ia-split3*") nil)
                        w2)
                    (= split-calls 0)
                    (= ask-calls 1)))))))

;; The question path is what the rest of the checks below exercise.
(setq ia/window-split-maximum 0)

;;; ---- the rule, with the batch gate lifted and aw-select stubbed
(let ((noninteractive nil))
  ;; a plain selected window takes the buffer; the choice never runs
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (let ((result (display-buffer (get-buffer-create "*ia-t1*"))))
        (check "plain window: the buffer takes the selected window"
               (eq result w1))
        (check "plain window: the choice never runs" (= calls 0)))))
  ;; a dedicated selected window asks; a dedicated choice asks again
  (set-window-dedicated-p w1 t)
  (let* ((ia/display-buffer-action-select 'auto)
         (w3 (split-window w2 nil 'below))
         (calls 0)
         (choices (list w2 w3)))
    (set-window-dedicated-p w2 t)
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _)
                 (setq calls (1+ calls))
                 (pop choices))))
      (let ((result (display-buffer (get-buffer-create "*ia-t2*"))))
        (check "dedicated choice: asked again" (= calls 2))
        (check "dedicated choice: the second choice gets the buffer"
               (eq result w3))
        (check "dedicated choice: the buffer is in the chosen window"
               (eq (window-buffer w3) (get-buffer "*ia-t2*")))))
    (set-window-dedicated-p w2 nil)
    (delete-window w3))
  ;; an aborted choice declines and the following action functions run
  (let ((result nil))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) nil)))
      (setq result (display-buffer (get-buffer-create "*ia-t3*"))))
    (check "aborted choice: a window is still returned"
           (and result (window-live-p result))))
  ;; in batch the rule declines without choosing
  (let ((noninteractive t)
        (calls 0)
        (result nil))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (setq result (display-buffer (get-buffer-create "*ia-t4*"))))
    (check "batch gate: the choice never runs" (= calls 0))
    (check "batch gate: a window is still returned"
           (and result (window-live-p result))))
  ;; a request that names a place is left to the caller
  (let ((calls 0))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) w2)))
      (let ((win (display-buffer (get-buffer-create "*ia-side*")
                                 '((display-buffer-in-side-window)
                                   (side . right)))))
        (check "a side request is left to the caller"
               (and (= calls 0)
                    (eq (window-parameter win 'window-side) 'right))))))
  ;; t selects the chosen window
  (select-window w1)
  (let ((ia/display-buffer-action-select t))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*ia-t5*"))
      (check "select t: the chosen window is selected"
             (eq (selected-window) w2))))
  ;; auto selects nothing and installs nothing
  (select-window w1)
  (let ((ia/display-buffer-action-select 'auto)
        (hook-before (length post-command-hook)))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*ia-t6*"))
      (check "select auto: the selection is unchanged"
             (eq (selected-window) w1))
      (check "select auto: no entry is installed"
             (= (length post-command-hook) hook-before))))
  ;; nil undoes a caller that selects, at the end of the command
  (select-window w1)
  (let ((ia/display-buffer-action-select nil)
        (hook-before (length post-command-hook)))
    (cl-letf (((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (let ((pop-up-windows t))
        (pop-to-buffer (get-buffer-create "*ia-t7*") t))
      (check "select nil: the caller selected during the command"
             (eq (selected-window) w2))
      (check "select nil: one entry is installed"
             (= (length post-command-hook) (1+ hook-before)))
      (run-hooks 'post-command-hook)
      (check "select nil: the selection returns at the end of the command"
             (eq (selected-window) w1))
      (check "select nil: the entry removed itself"
             (= (length post-command-hook) hook-before))))
  (select-window w1)
  (set-window-dedicated-p w1 nil))

;;; ---- the function list, read at display time
(let ((noninteractive nil)
      (probe (get-buffer-create "*ia-list-default*")))
  (set-window-buffer w2 probe)
  (select-window w1)
  (let ((ia/display-buffer-action-functions
         '(display-buffer-reuse-window
           display-buffer-same-window
           ia/display-buffer-action-choose-window)))
    (let ((win (display-buffer probe)))
      (check "the default list: one view, the existing window wins"
             (and (eq win w2)
                  (= 1 (length (get-buffer-window-list probe nil nil)))))))
  (set-window-buffer w1 (get-buffer-create "*ia-other*")))
(let ((noninteractive nil)
      (probe (get-buffer-create "*ia-list-same*")))
  (set-window-buffer w2 probe)
  (select-window w1)
  (let ((ia/display-buffer-action-functions
         '(display-buffer-same-window
           ia/display-buffer-action-choose-window)))
    (let ((win (display-buffer probe)))
      (check "a reordered list: two views, the selected window wins"
             (and (eq win w1)
                  (= 2 (length (get-buffer-window-list probe nil nil)))))))
  (set-window-buffer w1 (get-buffer-create "*ia-other2*")))
;; without the chooser the rule never asks
(let ((noninteractive nil)
      (calls 0))
  (set-window-dedicated-p w1 t)
  (let ((ia/display-buffer-action-functions '(display-buffer-reuse-window)))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (setq calls (1+ calls)) nil)))
      (display-buffer (get-buffer-create "*ia-night*"))
      (check "a list without the chooser never asks" (= calls 0))))
  (set-window-dedicated-p w1 nil))

;;; ---- the patched prefix: the ace path asks again on a utility choice
(let ((noninteractive nil)
      (pop-up-windows nil)
      (calls 0))
  (set-window-dedicated-p w2 t)
  (ace-other-window-prefix)
  (let ((choices (list w2 w1)))
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select)
               (lambda (&rest _)
                 (setq calls (1+ calls))
                 (pop choices))))
      (let ((result (display-buffer (get-buffer-create "*ia-t9*"))))
        (check "prefix: a dedicated choice asked again" (= calls 2))
        (check "prefix: the buffer is in the second choice"
               (eq (window-buffer w1) (get-buffer "*ia-t9*")))
        (check "prefix: the display returns that window" (eq result w1)))))
  (set-window-dedicated-p w2 nil))

;;; ---- the prefix splits under the maximum
(let ((noninteractive nil)
      (pop-up-windows nil)
      (split-calls 0)
      (ask-calls 0)
      (ia/window-split-maximum 4))
  (select-window w1)
  (cl-letf (((symbol-function 'aw-window-list) (lambda () (list w1 w2)))
            ((symbol-function 'display-buffer-pop-up-window)
             (lambda (_buffer _alist) (setq split-calls (1+ split-calls)) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w1)))
    (ace-other-window-prefix)
    (let ((result (display-buffer (get-buffer-create "*ia-prefix-split*"))))
      (check "prefix: under the maximum, the split decides"
             (and (eq result w2)
                  (= split-calls 1)
                  (= ask-calls 0))))))

;;; ---- the prefix's select option
(let ((noninteractive nil)
      (pop-up-windows nil))
  (select-window w1)
  (let ((ace-other-window-select t))
    (ace-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*ia-t10*"))
      (check "prefix select t: the chosen window is selected"
             (eq (selected-window) w2))))
  (setq display-buffer-overriding-action '(nil . nil))
  (select-window w1)
  (let ((ace-other-window-select 'auto))
    (ace-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (display-buffer (get-buffer-create "*ia-t11*"))
      (check "prefix select auto: the selection is unchanged"
             (eq (selected-window) w1))))
  (setq display-buffer-overriding-action '(nil . nil))
  (select-window w1)
  (let ((ace-other-window-select nil))
    (ace-other-window-prefix)
    (cl-letf (((symbol-function 'display-buffer-pop-up-window)
               (lambda (&rest _) nil))
              ((symbol-function 'aw-select) (lambda (&rest _) w2)))
      (pop-to-buffer (get-buffer-create "*ia-t12*") t))
    (check "prefix select nil: the caller selected during the command"
           (eq (selected-window) w2))
    (run-hooks 'post-command-hook)
    (check "prefix select nil: the selection returns at the end"
           (eq (selected-window) w1)))
  (setq display-buffer-overriding-action '(nil . nil)))

;;; ---- the default list reaches the split rule
(let ((noninteractive nil)
      (split-height-threshold 10)
      (split-width-threshold 20)
      (ia/window-split-maximum 4)
      (ask-calls 0))
  (set-window-dedicated-p w1 t)
  (select-window w1)
  (cl-letf (((symbol-function 'aw-window-list) (lambda () (list w1 w2)))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) nil)))
    (let ((probe (get-buffer-create "*ia-default-split*")))
      (let ((win (display-buffer probe)))
        (check "default list: under the maximum, `display-buffer' splits"
               (and win
                    (not (eq win w1))
                    (= ask-calls 0)
                    (eq (window-buffer win) probe))))))
  (set-window-dedicated-p w1 nil))

;;; ---- one window: a request for another window splits instead of reusing it
(let ((noninteractive nil)
      (pop-up-windows t)
      (split-height-threshold 10)
      (split-width-threshold 20))
  (delete-other-windows)
  (let ((start (selected-window)))
    (cl-letf (((symbol-function 'aw-select)
               (lambda (&rest _) (selected-window))))
      (let* ((probe (get-buffer-create "*ia-one-window*"))
             (win (display-buffer probe t)))
        (check "one window, ACTION t: a new window is split"
               (and win
                    (not (eq win start))
                    (= 2 (length (window-list)))
                    (eq (window-buffer win) probe)))
        (check "one window, ACTION t: the selected window keeps its buffer"
               (not (eq (window-buffer start) probe)))))))

;;; ---- the mode's disable removes only its entry
(ia/display-buffer-action-mode -1)
(check "final: the entry is removed, `display-buffer-base-action' untouched"
       (and (null (assq 'ia/display-buffer-action-control-p display-buffer-alist))
            (equal display-buffer-base-action '(nil . nil))))

(princ (if (zerop nfail) "\nALL PASSED\n"
         (format "\n%d CHECK(S) FAILED\n" nfail)))
(expect nfail :to-be 0))

(describe "ia display action"
  (it "runs the display checks"
    (ia/display-ask-checks)))
