;;; ia-tab-bar-modified-consult.el --- Consult integration for the tab bar  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/emacs-utils
;; Package-Requires: ((consult "0") (display-buffer-pivot "0.0.0"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The consult integration, the tab-switch commands and the built-in
;; overrides for the tab bar.  The candidates, history, sort, annotations
;; and the plain reader are in `display-buffer-pivot-tab-bar'.  The mode
;; sets `display-buffer-pivot-tab-bar-read-function' so the display
;; action's tab prompt uses the consult reader.

(require 'cl-lib)
(require 'consult)
(require 'display-buffer-pivot-tab-bar) ; The tab bar reader from the display-buffer-pivot package.

;; Pacify the compiler for dynamic overrides
(defvar marginalia-annotators)

;;; Code:

(defun ia/tab-bar-modified--purge-child-frames ()
  "Forcefully delete ALL child frames (visible or invisible).
[TRAP WARNING]: Wayland/PGTK Deadlock Prevention.  When
`current-window-configuration` is called, it captures invisible Corfu
frames.  Restoring that state during active minibuffer blocks deadlocks
the PGTK display server.  This aggressively sanitizes the environment
first."
  (dolist (frame (frame-list))
    (when (frame-parent frame)
      (delete-frame frame))))

(defun ia/tab-bar-modified--run-with-thrash-protection (callback)
  "Execute CALLBACK while freezing the active minibuffer height."
  (let* ((mini (active-minibuffer-window))
         (h (and mini (window-height mini))))
    (funcall callback)
    (when (and mini (window-live-p mini) h)
      (let ((delta (- h (window-height mini))))
        (unless (zerop delta)
          (ignore-errors (window-resize mini delta)))))))

(defun ia/tab-bar-modified--execute-switch (selected-key candidates)
  "Execute the tab switch or creation selected by SELECTED-KEY.
CANDIDATES is the alist from `display-buffer-pivot-tab-bar--get-candidates'; a
matching entry's index selects its tab, and any other name makes a new
tab with that name."
  (when (and selected-key (not (string= selected-key "")))
    (let* ((match (assoc-string selected-key candidates))
           (target-idx (nth 1 match))
           (target-name (if match (nth 2 match) selected-key)))
      (if target-idx
          (tab-bar-select-tab target-idx)
        (tab-bar-new-tab)
        (when display-buffer-pivot-tab-bar-sanitize-new-tab
          (set-window-prev-buffers (selected-window) nil)
          (set-window-next-buffers (selected-window) nil))
        (tab-bar-rename-tab target-name)))))

(defun ia/tab-bar-modified--build-state (candidates orig-index orig-tabs orig-wc)
  "Build a state closure for Consult previews of CANDIDATES.
ORIG-INDEX is the current tab's 1-based index, ORIG-TABS its tab list,
and ORIG-WC the window configuration to restore when the preview ends."
  (lambda (action cand)
    (cond
     ((and (eq action 'preview) cand)
      (let* ((match (assoc-string cand candidates))
             (target-idx (nth 1 match)))
        (when target-idx
          (ia/tab-bar-modified--run-with-thrash-protection
           (lambda () (tab-bar-select-tab target-idx))))))

     ((and (eq action 'preview) (not cand))
      (ia/tab-bar-modified--run-with-thrash-protection
       (lambda () (tab-bar-select-tab orig-index))))

     ((eq action 'return)
      (set-frame-parameter nil 'tabs orig-tabs)
      (set-window-configuration orig-wc)
      (tab-bar-select-tab orig-index)))))

(defun ia/tab-bar-modified--consult-read (prompt candidates initial)
  "Read a tab name from CANDIDATES with consult previews.
PROMPT is the prompt string.  INITIAL is the default candidate; an
empty string means a new tab.  Return the chosen name; an empty name
means a new tab."
  (ia/tab-bar-modified--purge-child-frames)
  (let* ((orig-index (1+ (tab-bar--current-tab-index)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration))
         (marginalia-annotators
          (if display-buffer-pivot-tab-bar-disable-marginalia
              nil
            (bound-and-true-p marginalia-annotators)))
         (history-delete-duplicates t)) ; Force native deduplication
    (unwind-protect
        (let ((completion-extra-properties
               (list :category 'tab
                     :display-sort-function
                     (if display-buffer-pivot-tab-bar-sort-function
                         (lambda (cands)
                           (funcall display-buffer-pivot-tab-bar-sort-function
                                    cands candidates))
                       #'identity))))
          (consult--read
           candidates
           :prompt prompt
           :default initial
           :category 'tab
           :sort nil
           :history (and display-buffer-pivot-tab-bar-enable-history
                         'display-buffer-pivot-tab-bar--history)
           :require-match nil
           :annotate (if display-buffer-pivot-tab-bar-disable-marginalia
                         (display-buffer-pivot-tab-bar--build-annotator
                          candidates)
                       nil)
           :state (ia/tab-bar-modified--build-state
                   candidates orig-index orig-tabs orig-wc)))
      ;; Unconditional cleanup
      (display-buffer-pivot-tab-bar--sanitize-history))))

;; --- Interactive Commands ---

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))

  (let* ((candidates (display-buffer-pivot-tab-bar--get-candidates))
         (current (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if
                             (lambda (pair) (eq (nth 1 pair) current))
                             candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (ia/tab-bar-modified--execute-switch
       (ia/tab-bar-modified--consult-read
        "Switch Workspace (or create new): " candidates default-cand)
       candidates))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (ia/tab-bar-modified--purge-child-frames)

  (let* ((candidates (display-buffer-pivot-tab-bar--get-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) current-idx)) candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (let ((history-delete-duplicates t)) ; Force native deduplication
        (ia/tab-bar-modified--execute-switch
         (unwind-protect
             (let ((marginalia-annotators (if display-buffer-pivot-tab-bar-disable-marginalia nil (bound-and-true-p marginalia-annotators)))
                   (completion-extra-properties
                    (list :category
                          'tab
                          :display-sort-function
                          (if display-buffer-pivot-tab-bar-sort-function
                              (lambda (cands) (funcall display-buffer-pivot-tab-bar-sort-function cands candidates))
                            #'identity)
                          :affixation-function
                          (if display-buffer-pivot-tab-bar-disable-marginalia
                              (let ((annotator (display-buffer-pivot-tab-bar--build-annotator candidates)))
                                (lambda (cands) (mapcar annotator cands)))
                            nil))))
               (completing-read "Switch to tab: "
                                candidates
                                nil nil nil
                                (and display-buffer-pivot-tab-bar-enable-history 'display-buffer-pivot-tab-bar--history)
                                default-cand))
           ;; Unconditional cleanup
           (display-buffer-pivot-tab-bar--sanitize-history))
         candidates)))))

(defun ia-advice/tab-bar-rename-tab-around (orig-fun &optional name arg)
  "Wrap `tab-bar-rename-tab` to provide rich history completion for tab names.
ORIG-FUN is the original `tab-bar-rename-tab'; NAME and ARG are its
arguments."
  (interactive
   (let* ((rich-cands (display-buffer-pivot-tab-bar--get-candidates t))
          (filtered-cands nil)
          (plain-cands nil))

     (ia/tab-bar-modified--purge-child-frames)

     (dolist (cand rich-cands)
       (let ((is-active (nth 1 cand)))
         (when (or (and is-active display-buffer-pivot-tab-bar-rename-include-active)
                   (and (not is-active) display-buffer-pivot-tab-bar-rename-enable-history))
           (push cand filtered-cands)
           (push (car cand) plain-cands))))

     (setq filtered-cands (nreverse filtered-cands))
     (setq plain-cands (nreverse plain-cands))

     (let* ((history-delete-duplicates t) ; Force native deduplication
            (selected-key
             (if (null plain-cands)
                 (read-string "New name for tab (leave blank for default name): ")
               (unwind-protect
                   (let ((marginalia-annotators
                          (if display-buffer-pivot-tab-bar-disable-marginalia
                              nil
                            (bound-and-true-p marginalia-annotators)))
                         (completion-extra-properties
                          (list
                           :category
                           'tab
                           :display-sort-function
                           (if display-buffer-pivot-tab-bar-sort-function
                               (lambda (cands)
                                 (funcall display-buffer-pivot-tab-bar-sort-function cands filtered-cands))
                             #'identity)
                           :affixation-function
                           (if display-buffer-pivot-tab-bar-disable-marginalia
                               (let ((annotator (display-buffer-pivot-tab-bar--build-annotator filtered-cands)))
                                 `(lambda (cands)
                                   (mapcar ,annotator cands)))
                             nil)
                           )))
                     (completing-read
                      "New name for tab (leave blank for default name): "
                      plain-cands nil nil nil
                      (and display-buffer-pivot-tab-bar-rename-enable-history 'display-buffer-pivot-tab-bar--history)))
                 ;; Unconditional cleanup
                 (display-buffer-pivot-tab-bar--sanitize-history))))
            (match (assoc-string selected-key filtered-cands))
            (new-name (if match (nth 2 match) selected-key)))
       (list new-name current-prefix-arg))))
  (funcall orig-fun name arg))

(defun ia/tab-bar-modified-move-current-left ()
  "Move the current tab one position to the left in the header line."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))
  (if (> (tab-bar--current-tab-index) 0)
      (tab-bar-move-tab -1)
    (user-error "Tab is already at the leftmost position")))

(defun ia/tab-bar-modified-move-current-right ()
  "Move the current tab one position to the right in the header line."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))
  (let ((current-idx (tab-bar--current-tab-index))
        (total-tabs (length (tab-bar-tabs))))
    (if (< current-idx (1- total-tabs))
        (tab-bar-move-tab 1)
      (user-error "Tab is already at the rightmost position"))))

(defun ia/tab-bar-modified--consult-read-tab-name (prompt candidates initial)
  "Read a tab name with consult previews.
PROMPT, CANDIDATES and INITIAL are the arguments
`display-buffer-pivot-tab-bar-read-function' receives."
  (ia/tab-bar-modified--consult-read prompt candidates initial))

(defvar ia/tab-bar-modified--read-function nil
  "The tab reader to restore when the consult mode is disabled.")

(define-minor-mode ia/tab-bar-modified-consult-mode
  "Global minor mode to manage index-safe tab switching and built-in overrides."
  :global t
  :group 'display-buffer-pivot-tab-bar
  :keymap (make-sparse-keymap)
  (if ia/tab-bar-modified-consult-mode
      (progn
        (setq ia/tab-bar-modified--read-function
              display-buffer-pivot-tab-bar-read-function)
        (setq display-buffer-pivot-tab-bar-read-function
              #'ia/tab-bar-modified--consult-read-tab-name)
        (advice-add 'tab-bar-switch-to-tab :override 'ia-advice/tab-bar-switch-indexed-override)
        (advice-add 'tab-bar-rename-tab :around 'ia-advice/tab-bar-rename-tab-around))
    (when (eq display-buffer-pivot-tab-bar-read-function
              #'ia/tab-bar-modified--consult-read-tab-name)
      (setq display-buffer-pivot-tab-bar-read-function
            ia/tab-bar-modified--read-function))
    (advice-remove 'tab-bar-switch-to-tab 'ia-advice/tab-bar-switch-indexed-override)
    (advice-remove 'tab-bar-rename-tab 'ia-advice/tab-bar-rename-tab-around)))

(provide 'ia-tab-bar-modified-consult)

;;; ia-tab-bar-modified-consult.el ends here
