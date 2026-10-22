;;; -*- lexical-binding: t; -*-
;; Behavioural checks for the tab and frame target of
;; ia/display-buffer-action.  Run: make test
(require 'ia-display-buffer-action)
(require 'ia-window-prefix-pivot)

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

;;; ---- what the ACTION and ALIST ask for
(let ((ia/display-buffer-action--action
       '((display-buffer-in-tab) (inhibit-same-window . nil))))
  (check "target: a tab action asks for a tab"
         (eq (ia/display-buffer-action--target
              '((inhibit-same-window . nil)))
             'tab)))
(let ((ia/display-buffer-action--action '((display-buffer-in-new-tab))))
  (check "target: a new-tab action asks for a tab"
         (eq (ia/display-buffer-action--target nil) 'tab)))
(let ((ia/display-buffer-action--action nil))
  (check "target: tab-name asks for a tab"
         (eq (ia/display-buffer-action--target '((tab-name . "x"))) 'tab))
  (check "target: pop-up-frames asks for a frame"
         (eq (ia/display-buffer-action--target '((pop-up-frames . t)))
             'frame)))
(let ((ia/display-buffer-action--action '((display-buffer-pop-up-frame))))
  (check "target: a frame action asks for a frame"
         (eq (ia/display-buffer-action--target nil) 'frame)))
(let ((ia/display-buffer-action--action '((display-buffer-pop-up-window))))
  (check "target: a plain window action asks for no target"
         (null (ia/display-buffer-action--target nil))))
(let ((ia/display-buffer-action--action
       '((display-buffer-in-child-frame) (parent-frame . nil))))
  (check "target: a child frame is left to the caller"
         (null (ia/display-buffer-action--target '((parent-frame))))))

;;; ---- stubs
(defvar tab-calls)
(defvar ask-seen)
(defvar answers)
(setq tab-calls nil)
(defun tab-record (name &rest args)
  (push (cons name args) tab-calls))
(defun tab-stub-tabs ()
  '(((name . "one") (index . 0))
    ((name . "two") (index . 1))))
(defun ask-stub (mode-line)
  (setq ask-seen (list mode-line aw-scope aw-ignore-current
                       aw-dispatch-when-more-than aw-dispatch-always))
  w2)

;;; ---- the tab question and its window
(let ((noninteractive nil)
      (tab-calls nil)
      (ask-seen nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (tab-record 'select index)))
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "two")))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab1*") '((tab-name . "two")))))
      (check "tab: an existing name selects that tab"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (equal (nreverse tab-calls) '((select 2))))))))
(let ((noninteractive nil)
      (tab-calls nil)
      (ask-seen nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "")))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab2*") '((tab-group . "work")))))
      (check "tab: an empty name makes a new tab"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'tab)
                  (equal (nreverse tab-calls) '((new) (group "work")))))))
  (check "tab: the window question uses the tab frame and reads a key"
         (equal ask-seen '("Display buffer in window" frame nil 0 nil))))
(let ((noninteractive nil)
      (tab-calls nil))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (tab-record 'new)))
            ((symbol-function 'tab-bar-rename-tab)
             (lambda (name) (tab-record 'rename name)))
            ((symbol-function 'tab-bar-change-tab-group)
             (lambda (group) (tab-record 'group group)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub)
            ((symbol-function 'completing-read) (lambda (&rest _) "three")))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab3*") nil)))
      (check "tab: a new name makes a tab with that name"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'tab)
                  (equal (nreverse tab-calls)
                         '((new) (rename "three"))))))))

;;; ---- a window already showing the buffer
(let ((noninteractive nil)
      (ask-calls 0))
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'get-buffer-window) (lambda (&rest _) w2))
            ((symbol-function 'aw-select)
             (lambda (&rest _) (setq ask-calls (1+ ask-calls)) w1)))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab-reuse*") '((tab-name . "two")))))
      (check "tab: a window showing the buffer is reused without a question"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (zerop ask-calls))))))

;;; ---- a chosen window that cannot display asks again
(let ((noninteractive nil)
      (calls 0))
  (set-window-dedicated-p w1 t)
  (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select)
             (lambda (&rest _)
               (setq calls (1+ calls))
               (if (= calls 1) w1 w2))))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab-ask*") '((tab-name . "two")))))
      (check "tab: a dedicated choice asks again"
             (and (eq (car-safe result) w2) (= calls 2)))))
  (set-window-dedicated-p w1 nil))

;;; ---- the tab package's reader supplies the name
(let ((original (symbol-function 'ia/tab-bar-modified-read-tab-name)))
  (unwind-protect
      (progn
        (fset 'ia/tab-bar-modified-read-tab-name
              (lambda (&optional _initial) "two"))
        (let ((noninteractive nil)
              (tab-calls nil)
              (reader-calls 0))
          (cl-letf (((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
                    ((symbol-function 'tab-bar-select-tab)
                     (lambda (index) (tab-record 'select index)))
                    ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
                    ((symbol-function 'aw-select) #'ask-stub)
                    ((symbol-function 'completing-read)
                     (lambda (&rest _) (setq reader-calls (1+ reader-calls)) "")))
            (let ((result (ia/display-buffer-action-tab
                           (get-buffer-create "*tab-reader*") nil)))
              (check "tab: the tab package's reader supplies the name"
                     (and (eq (car-safe result) w2)
                          (equal (nreverse tab-calls) '((select 2)))
                          (zerop reader-calls)))))))
    (fset 'ia/tab-bar-modified-read-tab-name original)))

;;; ---- the split help follows the user's dispatch list
(let ((aw-dispatch-alist
       '((?s aw-split-window-vert "Split Vert Window")
         (?x aw-delete-window "Delete Window"))))
  (let ((actions (ia/display-buffer-action--split-actions)))
    (check "split help: the user's split key is used"
           (string-match-p "s: Split Vert Window"
                           (ia/display-buffer-action--split-help actions)))
    (check "split help: a delete action is left out"
           (not (string-match-p "Delete Window"
                                (ia/display-buffer-action--split-help actions))))))

;;; ---- the sole window's key
(let ((aw-dispatch-alist '((?s aw-split-window-vert "Split Test"))))
  (cl-letf (((symbol-function 'read-char) (lambda (&rest _) ?x)))
    (check "sole window: any other key uses it"
           (eq (ia/display-buffer-action--choose-sole-window w1) w1)))
  (cl-letf (((symbol-function 'read-char) (lambda (&rest _) ?s))
            ((symbol-function 'aw-split-window-vert)
             (lambda (_window) w2)))
    (check "sole window: a split key uses the new window"
           (eq (ia/display-buffer-action--choose-sole-window w1) w2))))

;;; ---- batch asks nothing
(let ((noninteractive t))
  (check "tab: batch asks nothing"
         (null (ia/display-buffer-action-tab
                (get-buffer-create "*tab4*") '((tab-name . "four")))))
  (check "frame: batch asks nothing"
         (null (ia/display-buffer-action--frame
                (get-buffer-create "*frame3*") '((pop-up-frames . t))))))

;;; ---- the frame question
(let ((noninteractive nil)
      (calls nil))
  (cl-letf (((symbol-function 'ia/display-buffer-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _)
               (or (frame-parameter (selected-frame) 'name) "frame")))
            ((symbol-function 'select-frame-set-input-focus)
             (lambda (frame) (setq calls (list 'focus frame))))
            ((symbol-function 'select-frame)
             (lambda (frame) (setq calls (list 'select frame))))
            ((symbol-function 'tab-bar-tabs) (lambda () '(((name . "one")))))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (check "frame: a title selects that frame"
           (and (eq (ia/display-buffer-action--frame
                     (get-buffer-create "*frame1*") nil)
                    w2)
                (eq (cadr calls) (selected-frame))))))
(let ((noninteractive nil)
      (calls nil))
  (cl-letf (((symbol-function 'ia/display-buffer-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _) ""))
            ((symbol-function 'display-buffer-pop-up-frame)
             (lambda (&rest _) (setq calls (list 'new)) w2)))
    (check "frame: an empty title makes a new frame"
           (and (eq (ia/display-buffer-action--frame
                     (get-buffer-create "*frame2*")
                     '((pop-up-frames . t)))
                    w2)
                (equal calls '(new))))))
(let ((noninteractive nil)
      (tab-calls nil)
      (answers (list (frame-parameter (selected-frame) 'name) "two")))
  (cl-letf (((symbol-function 'ia/display-buffer-action--frames)
             (lambda (&rest _) (list (selected-frame))))
            ((symbol-function 'completing-read)
             (lambda (&rest _) (pop answers)))
            ((symbol-function 'select-frame-set-input-focus) #'ignore)
            ((symbol-function 'tab-bar-tabs)
             (lambda ()
               '(((name . "one") (index . 0))
                 ((name . "two") (index . 1)))))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (tab-record 'select index)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (check "frame: a frame with several tabs asks the tab, then the window"
           (and (eq (ia/display-buffer-action--frame
                     (get-buffer-create "*frame4*") nil)
                    w2)
                (equal (nreverse tab-calls) '((select 2)))))))

;;; ---- the core tab action through display-buffer
(ia/display-buffer-action-mode +1)
(let ((noninteractive nil)
      (asked 0)
      (made 0))
  (cl-letf (((symbol-function 'tab-bar-new-tab)
             (lambda (&rest _) (setq made (1+ made))))
            ((symbol-function 'tab-bar-tabs) #'tab-stub-tabs)
            ((symbol-function 'tab-bar-select-tab) #'ignore)
            ((symbol-function 'tab-bar-rename-tab) #'ignore)
            ((symbol-function 'tab-bar-change-tab-group) #'ignore)
            ((symbol-function 'completing-read)
             (lambda (&rest _) (setq asked (1+ asked)) ""))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) nil))
            ((symbol-function 'aw-select) #'ask-stub))
    (let ((win (display-buffer (get-buffer-create "*tab-core*")
                               '((display-buffer-in-tab)
                                 (inhibit-same-window . nil)))))
      (check "core: a tab ACTION reaches the tab question"
             (and (eq win w2) (= asked 1) (= made 1))))))

;;; ---- the core frame action through display-buffer
(let ((noninteractive nil)
      (asked 0)
      (popped 0))
  (cl-letf (((symbol-function 'ia/display-buffer-action--frames)
             (lambda (&rest _) nil))
            ((symbol-function 'completing-read)
             (lambda (&rest _) (setq asked (1+ asked)) ""))
            ((symbol-function 'display-buffer-pop-up-frame)
             (lambda (&rest _) (setq popped (1+ popped)) w2)))
    (let ((win (display-buffer (get-buffer-create "*frame-core*")
                               display-buffer--other-frame-action)))
      (check "core: an other-frame ACTION reaches the frame question"
             (and (eq win w2) (= asked 1) (= popped 1))))))

;;; ---- the reusable tab
(let ((noninteractive nil)
      (calls nil))
  (cl-letf (((symbol-function 'tab-bar-get-buffer-tab)
             (lambda (&rest _) (list (cons 'frame (selected-frame))
                                     (cons 'index 0))))
            ((symbol-function 'select-frame-set-input-focus)
             (lambda (frame) (push (list 'focus frame) calls)))
            ((symbol-function 'tab-bar-select-tab)
             (lambda (index) (push (list 'select index) calls)))
            ((symbol-function 'get-buffer-window) (lambda (&rest _) w2)))
    (let ((result (ia/display-buffer-action-tab
                   (get-buffer-create "*tab-reuse2*")
                   '((reusable-frames . t)))))
      (check "tab: a reusable tab is selected before the window rule"
             (and (eq (car-safe result) w2)
                  (eq (cdr-safe result) 'reuse)
                  (equal (nreverse calls)
                         (list (list 'focus (selected-frame))
                               (list 'select 1))))))))

;;; ---- the other-tab prefix
(let ((noninteractive nil))
  (cl-letf (((symbol-function 'ia/display-buffer-action-tab)
             (lambda (_buffer _alist) (cons w2 'tab))))
    (ia/other-tab-prefix)
    (let ((win (display-buffer (get-buffer-create "*otp*"))))
      (check "other-tab prefix: the tab step decides"
             (and (eq win w2)
                  (eq (window-buffer w2) (get-buffer "*otp*")))))))
(let ((noninteractive nil)
      (calls 0))
  (cl-letf (((symbol-function 'ia/display-buffer-action-tab)
             (lambda (_buffer _alist)
               (setq calls (1+ calls))
               (display-buffer (get-buffer-create "*nested*"))
               (cons w2 'tab))))
    (ia/other-tab-prefix)
    (let ((win (display-buffer (get-buffer-create "*outer*"))))
      (check "other-tab prefix: a nested display does not ask again"
             (and (eq win w2)
                  (= calls 1)
                  (eq (window-buffer w2) (get-buffer "*outer*")))))))
(ia/display-buffer-action-mode -1)

(princ (if (zerop nfail) "\nALL PASSED\n"
         (format "\n%d CHECK(S) FAILED\n" nfail)))
(kill-emacs (if (zerop nfail) 0 1))
