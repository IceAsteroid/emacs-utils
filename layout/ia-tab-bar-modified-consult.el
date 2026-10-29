;;; ia-tab-bar-modified-consult.el --- Consult integration for the tab bar  -*- lexical-binding: t; -*-

;; Author: IceAsteroid
;; URL: https://github.com/IceAsteroid/emacs-utils
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; The consult integration, the tab-switch commands and the built-in
;; overrides for the tab bar.  This library requires `consult` and the
;; `disbuf-pivot` package; install them separately.  The
;; candidates, history, sort, annotations and the consult reader are in
;; `disbuf-pivot-tab-bar' and its optional
;; `disbuf-pivot-tab-bar-consult' library.  The mode installs
;; that library's reader; the overrides and the rename advice call its
;; child-frame cleanup.

(require 'cl-lib)
(require 'dp-tab-bar-consult) ; The consult reader from the disbuf-pivot package.

;; Pacify the compiler for dynamic overrides
(defvar marginalia-annotators)

;;; Code:

(defun ia/tab-bar-modified--execute-switch (selected-key candidates)
  "Execute the tab switch or creation selected by SELECTED-KEY.
CANDIDATES is the alist from `disbuf-pivot-tab-bar--get-candidates'; a
matching entry's index selects its tab, and any other name makes a new
tab with that name."
  (when (and selected-key (not (string= selected-key "")))
    (let* ((match (assoc-string selected-key candidates))
           (target-idx (nth 1 match))
           (target-name (if match (nth 2 match) selected-key)))
      (if target-idx
          (tab-bar-select-tab target-idx)
        (tab-bar-new-tab)
        (when dp-tab-bar-sanitize-new-tab
          (set-window-prev-buffers (selected-window) nil)
          (set-window-next-buffers (selected-window) nil))
        (tab-bar-rename-tab target-name)))))

;; --- Interactive Commands ---

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))

  (let* ((candidates (dp-tab-bar--get-candidates))
         (current (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if
                             (lambda (pair) (eq (nth 1 pair) current))
                             candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (ia/tab-bar-modified--execute-switch
       (dp-tab-bar-consult-read
        "Switch Workspace (or create new): " candidates default-cand)
       candidates))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (dp-tab-bar-consult-purge-child-frames)

  (let* ((candidates (dp-tab-bar--get-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) current-idx)) candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (let ((history-delete-duplicates t)) ; Force native deduplication
        (ia/tab-bar-modified--execute-switch
         (unwind-protect
             (let ((marginalia-annotators (if dp-tab-bar-disable-marginalia nil (bound-and-true-p marginalia-annotators)))
                   (completion-extra-properties
                    (list :category
                          'tab
                          :display-sort-function
                          (if dp-tab-bar-sort-function
                              (lambda (cands) (funcall dp-tab-bar-sort-function cands candidates))
                            #'identity)
                          :affixation-function
                          (if dp-tab-bar-disable-marginalia
                              (let ((annotator (dp-tab-bar--build-annotator candidates)))
                                (lambda (cands) (mapcar annotator cands)))
                            nil))))
               (completing-read "Switch to tab: "
                                candidates
                                nil nil nil
                                (and dp-tab-bar-enable-history 'dp-tab-bar--history)
                                default-cand))
           ;; Unconditional cleanup
           (dp-tab-bar--sanitize-history))
         candidates)))))

(defun ia-advice/tab-bar-rename-tab-around (orig-fun &optional name arg)
  "Wrap `tab-bar-rename-tab` to provide rich history completion for tab names.
ORIG-FUN is the original `tab-bar-rename-tab'; NAME and ARG are its
arguments."
  (interactive
   (let* ((rich-cands (dp-tab-bar--get-candidates t))
          (filtered-cands nil)
          (plain-cands nil))

     (dp-tab-bar-consult-purge-child-frames)

     (dolist (cand rich-cands)
       (let ((is-active (nth 1 cand)))
         (when (or (and is-active dp-tab-bar-rename-include-active)
                   (and (not is-active) dp-tab-bar-rename-enable-history))
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
                          (if dp-tab-bar-disable-marginalia
                              nil
                            (bound-and-true-p marginalia-annotators)))
                         (completion-extra-properties
                          (list
                           :category
                           'tab
                           :display-sort-function
                           (if dp-tab-bar-sort-function
                               (lambda (cands)
                                 (funcall dp-tab-bar-sort-function cands filtered-cands))
                             #'identity)
                           :affixation-function
                           (if dp-tab-bar-disable-marginalia
                               (let ((annotator (dp-tab-bar--build-annotator filtered-cands)))
                                 `(lambda (cands)
                                   (mapcar ,annotator cands)))
                             nil)
                           )))
                     (completing-read
                      "New name for tab (leave blank for default name): "
                      plain-cands nil nil nil
                      (and dp-tab-bar-rename-enable-history 'dp-tab-bar--history)))
                 ;; Unconditional cleanup
                 (dp-tab-bar--sanitize-history))))
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

(defvar ia/tab-bar-modified--read-function nil
  "The tab reader to restore when the consult mode is disabled.")

(define-minor-mode ia/tab-bar-modified-consult-mode
  "Global minor mode to manage index-safe tab switching and built-in overrides."
  :global t
  :group 'dp-tab-bar
  :keymap (make-sparse-keymap)
  (if ia/tab-bar-modified-consult-mode
      (progn
        (setq ia/tab-bar-modified--read-function
              dp-tab-bar-read-function)
        (setq dp-tab-bar-read-function
              #'dp-tab-bar-consult-read-tab-name)
        (advice-add 'tab-bar-switch-to-tab :override 'ia-advice/tab-bar-switch-indexed-override)
        (advice-add 'tab-bar-rename-tab :around 'ia-advice/tab-bar-rename-tab-around))
    (when (eq dp-tab-bar-read-function
              #'dp-tab-bar-consult-read-tab-name)
      (setq dp-tab-bar-read-function
            ia/tab-bar-modified--read-function))
    (advice-remove 'tab-bar-switch-to-tab 'ia-advice/tab-bar-switch-indexed-override)
    (advice-remove 'tab-bar-rename-tab 'ia-advice/tab-bar-rename-tab-around)))

(provide 'ia-tab-bar-modified-consult)

;;; ia-tab-bar-modified-consult.el ends here
;; Local Variables:
;; read-symbol-shorthands: (("dp-" . "disbuf-pivot-"))
;; End:
