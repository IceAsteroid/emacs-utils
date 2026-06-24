;;; ia-tab-bar-modified-consult.el --- tab-bar-mode modified & consult features for tab-bar-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;;

(require 'cl-lib)

;;; Code:

(defgroup ia/tab-bar-modified nil
  "Customizations for index-safe tab bar management."
  :group 'tab-bar)

(defcustom ia/tab-bar-modified-enable-history nil
  "Non-nil to enable history tracking and display closed tabs as candidates."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-sanitize-new-tab nil
  "Non-nil to not bring previous selected buffer window to the new tab.
As to not show the buffer window in the tab line header when
`global-tab-line-mode' is enabled."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-history-limit 20
  "Maximum number of history candidates to persist for tab names."
  :type 'integer
  :group 'ia/tab-bar-modified
  :set (lambda (symbol value)
         (set-default symbol value)
         (put 'ia/tab-bar-modified--history 'history-length value)))

(defvar ia/tab-bar-modified--history nil
  "Tracked history list containing raw and formatted selection entries.
Shared history for `tab-switch', it alias `tab-bar-switch-to-tab' and
`ia/consult-tab-switch'.")

(defun ia/tab-bar-modified--extract-raw-name (str)
  "Extract the clean, raw tab name from a formatted display string STR."
  (cond
   ((string-match "\\`\\[[0-9]+\\] \\(.*\\)\\'" str)
    (match-string 1 str))
   ((string-match "\\`\\(.*\\) \\[closed\\]\\'" str)
    (match-string 1 str))
   (t str)))

(defun ia/tab-bar-modified--get-candidates ()
  "Generate an alist of active tabs combined with parsed history entries if enabled."
  (let* ((tabs (tab-bar-tabs))
         (active-names nil)
         ;; 1. Build active tab candidates
         (candidates (cl-loop for tab in tabs
                              for idx from 1
                              for name = (alist-get 'name tab)
                              do (push name active-names)
                              collect (cons (format "[%d] %s" idx name)
                                            (cons idx name)))))

    ;; 2. Parse and build closed history candidates dynamically (only if enabled)
    (if (not ia/tab-bar-modified-enable-history)
        candidates
      (let ((history-cands nil)
            (seen-history nil))
        (dolist (hist-item ia/tab-bar-modified--history)
          (when (stringp hist-item)
            (let ((raw-name (ia/tab-bar-modified--extract-raw-name hist-item)))
              (unless (or (string= raw-name "")
                          (member raw-name active-names)
                          (member raw-name seen-history))
                (push raw-name seen-history)
                (push (cons (format "%s [closed]" raw-name)
                            (cons nil raw-name))
                      history-cands)))))
        (append candidates (nreverse history-cands))))))

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))
  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (orig-index (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (cadr pair) orig-index)) candidates)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration))
         (selected-key
          (unwind-protect
              (consult--read
               candidates
               :prompt "Switch Workspace (or create new): "
               :default default-cand
               :category 'tab
               ;; Only feed the history variable to the prompt if history tracking is enabled
               :history (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
               :require-match nil
               :state (lambda (action cand)
                        (when (and (eq action 'preview) cand)
                          (let* ((match (cdr (assoc cand candidates)))
                                 (target-idx (car match)))
                            (when target-idx
                              (tab-bar-select-tab target-idx))))))
            (tab-bar-select-tab orig-index)
            (set-frame-parameter nil 'tabs orig-tabs)
            (set-window-configuration orig-wc))))

    ;; Execution Phase
    (when (and selected-key (not (string= selected-key "")))
      (let* ((match (cdr (assoc selected-key candidates)))
             (target-idx (car match))
             (target-name (or (cdr match) selected-key)))

        (if target-idx
            (tab-bar-select-tab target-idx)
          (tab-bar-new-tab)
          (when ia/tab-bar-modified-sanitize-new-tab
            (set-window-prev-buffers (selected-window) nil)
            (set-window-next-buffers (selected-window) nil))
          (tab-bar-rename-tab target-name))))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (cadr pair) current-idx)) candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (let* ((user-input (completing-read "Switch to tab: "
                                          candidates
                                          nil nil nil
                                          (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
                                          default-cand))
             (match (cdr (assoc user-input candidates)))
             (target-idx (car match))
             (target-name (or (cdr match) user-input)))

        (if target-idx
            (tab-bar-select-tab target-idx)
          (tab-bar-new-tab)
          (when ia/tab-bar-modified-sanitize-new-tab
            (set-window-prev-buffers (selected-window) nil)
            (set-window-next-buffers (selected-window) nil))
          (tab-bar-rename-tab target-name))))))

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

(define-minor-mode ia/tab-bar-modified-consult-mode
  "Global minor mode to manage index-safe tab switching and built-in overrides."
  :global t
  :group 'ia/tab-bar-modified
  :keymap (make-sparse-keymap)
  (if ia/tab-bar-modified-consult-mode
      (advice-add 'tab-bar-switch-to-tab :override 'ia-advice/tab-bar-switch-indexed-override)
    (advice-remove 'tab-bar-switch-to-tab 'ia-advice/tab-bar-switch-indexed-override)))

(provide 'ia-tab-bar-modified-consult)

;;; ia-tab-bar-modified-consult.el ends here
