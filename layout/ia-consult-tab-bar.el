;;; ia-consult-tab-bar.el --- consult for tab-bar-mode

;;; Commentary:
;; 

  ;; This feature is achieved by the heavy help of Gemini Flash Extended Model.
(defun my/tab-bar--indexed-candidates ()
  "Generate a clean alist of (\"[index] name\" . index) for all tabs."
  (cl-loop for tab in (tab-bar-tabs)
           for idx from 1
           collect (cons (format "[%d] %s" idx (alist-get 'name tab)) idx)))

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))
  (let* ((candidates (my/tab-bar--indexed-candidates))
         (orig-index (1+ (tab-bar--current-tab-index))) ; MODIFIED: Track starting index
         (default-cand (car (rassq orig-index candidates)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration))
         (selected-key
          (unwind-protect
              (consult--read
               candidates
               :prompt "Switch Workspace (or create new): "
               :default default-cand
               :category 'tab
               :require-match nil  ; Allow arbitrary text for new tabs
               :state (lambda (action cand)
                        (when (and (eq action 'preview) cand)
                          (let ((target-idx (cdr (assoc cand candidates))))
                            (when target-idx
                              (tab-bar-select-tab target-idx))))))
            ;; MODIFIED: Precise, multi-layered state rollback
            (tab-bar-select-tab orig-index)          ; Step 1: Sync active tab index back
            (set-frame-parameter nil 'tabs orig-tabs) ; Step 2: Restore pristine ledger
            (set-window-configuration orig-wc))))    ; Step 3: Restore pristine window layout
    ;; Execution Phase
    (when (and selected-key (not (string= selected-key "")))
      (let ((final-idx (cdr (assoc selected-key candidates))))
        (if final-idx
            ;; Found an existing indexed tab -> switch to it
            (tab-bar-select-tab final-idx)
          ;; No match found -> safely provision a new workspace
          (tab-bar-new-tab)
          (tab-bar-rename-tab selected-key))))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (let* ((candidates (my/tab-bar--indexed-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (rassq current-idx candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (let* ((selected (completing-read "Switch to tab: "
                                        candidates ;; Native alist optimization
                                        nil t nil 'tab-bar-history default-cand))
             (target-idx (cdr (assoc selected candidates))))
        (if target-idx
            (tab-bar-select-tab target-idx)
          (user-error "Invalid tab selected"))))))

(defcustom ia/tab-switch-binding "C-x t RET"
  "Key string used to trigger `ia/consult-tab-switch` when the mode is active."
  :type 'string
  :group 'tab-bar)

(define-minor-mode ia/tab-bar-setup-mode
  "Global minor mode to manage index-safe tab switching and built-in overrides."
  :global t
  :group 'tab-bar
  ;; 1. Use the built-in inline keymap generator safely linked to your defcustom
  :keymap (let ((map (make-sparse-keymap)))
            (when (and ia/tab-switch-binding (not (string= ia/tab-switch-binding "")))
              (keymap-set map ia/tab-switch-binding 'ia/consult-tab-switch))
            map)
  ;; 2. Body handles only the volatile advice engine state toggles
  (if ia/tab-bar-setup-mode
      (advice-add 'tab-bar-switch-to-tab :override 'ia-advice/tab-bar-switch-indexed-override)
    (advice-remove 'tab-bar-switch-to-tab 'ia-advice/tab-bar-switch-indexed-override)))

(provide 'ia-consult-tab-bar)

;;; ia-consult-tab-bar.el ends here
