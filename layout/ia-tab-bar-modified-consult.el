;;; ia-tab-bar-modified-consult.el --- Tab bar modifications -*- lexical-binding: t; -*-

;;; Commentary:
;; A highly optimized, index-safe tab bar management module.
;; Provides native UI enhancements, Consult integration, and history tracking.

(require 'cl-lib)
(require 'consult)

;; Pacify the compiler for dynamic overrides
(defvar marginalia-annotators)

;;; Code:

(defgroup ia/tab-bar-modified nil
  "Customizations for index-safe tab bar management."
  :group 'tab-bar)

(defcustom ia/tab-bar-modified-enable-history t
  "Non-nil to enable history tracking and display closed tabs as candidates."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-sanitize-new-tab nil
  "Non-nil to not bring previous selected buffer window to the new tab."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-disable-marginalia t
  "Non-nil to natively suppress Marginalia during tab switching."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-show-extra-states nil
  "Non-nil to display the active buffer, window count, and group in completion."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-rename-include-active t
  "Non-nil to include active tab names as candidates when renaming a tab."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-rename-enable-history t
  "Non-nil to include closed tab history as candidates when renaming a tab."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-history-limit 20
  "Maximum number of history candidates to persist for tab names."
  :type 'integer
  :group 'ia/tab-bar-modified
  :set (lambda (symbol value)
         (set-default symbol value)
         (put 'ia/tab-bar-modified--history 'history-length value)))

(defcustom ia/tab-bar-modified-sort-function #'ia/tab-bar-modified-sort-active-first
  "Function to sort completion candidates before rendering."
  :type '(choice (const :tag "Active Tabs First" ia/tab-bar-modified-sort-active-first)
                 (const :tag "Let Frontend Sort" nil)
                 (function :tag "Custom Sort Function"))
  :group 'ia/tab-bar-modified)

(defvar ia/tab-bar-modified--history nil
  "Tracked history list containing raw selection entries.")

;; --- Custom Faces ---

(defface ia/tab-bar-modified-index-face
  '((t :inherit font-lock-type-face))
  "Face for active tab indices."
  :group 'ia/tab-bar-modified)

(defface ia/tab-bar-modified-closed-face
  '((t :inherit shadow))
  "Face for closed history tab indicators."
  :group 'ia/tab-bar-modified)

(defface ia/tab-bar-modified-buffer-face
  '((t :inherit font-lock-doc-face))
  "Face for tab buffer names."
  :group 'ia/tab-bar-modified)

(defface ia/tab-bar-modified-window-face
  '((t :inherit font-lock-constant-face))
  "Face for tab window counts."
  :group 'ia/tab-bar-modified)

(defface ia/tab-bar-modified-group-face
  '((t :inherit font-lock-comment-face))
  "Face for tab group names."
  :group 'ia/tab-bar-modified)

;; --- Core Logic ---

(defun ia/tab-bar-modified-sort-active-first (cands candidates-alist)
  "Sort CANDS so live tabs dynamically bubble above closed history tabs."
  (let ((active nil)
        (closed nil))
    (dolist (cand cands)
      (if (nth 1 (assoc-string cand candidates-alist))
          (push cand active)
        (push cand closed)))
    (setq active (sort active (lambda (a b)
                                (< (nth 1 (assoc-string a candidates-alist))
                                   (nth 1 (assoc-string b candidates-alist))))))
    (append active (nreverse closed))))

(defun ia/tab-bar-modified--extract-visible-buffers (ws)
  "Recursively extract only currently visible buffers from a window state WS."
  (let ((buffers nil))
    (cl-labels ((walk (node)
                  (cond
                   ((and (consp node) (eq (car node) 'buffer) (stringp (cadr node)))
                    (push (cadr node) buffers))
                   ((consp node)
                    (walk (car node))
                    (walk (cdr node))))))
      (walk ws))
    (nreverse buffers)))

(defun ia/tab-bar-modified--get-tab-data (tab)
  "Extract a static list of (BUFFER-STRING WINDOW-COUNT GROUP) from TAB."
  (let* ((ws (alist-get 'ws tab))
         (group (alist-get 'group tab))
         (is-current (eq (car tab) 'current-tab))
         buf-str win-count)

    (if is-current
        (let ((wins (window-list nil 'no-minibuf)))
          (setq win-count (length wins)
                buf-str (mapconcat (lambda (w) (buffer-name (window-buffer w))) wins " ")
                group (or group (frame-parameter nil 'tab-bar-group))))
      (if ws
          (let ((bufs (ia/tab-bar-modified--extract-visible-buffers ws)))
            (setq win-count (max 1 (length bufs))
                  buf-str (if bufs (mapconcat #'identity bufs " ") "unknown")))
        (setq win-count 0
              buf-str "unknown")))

    (list buf-str win-count group)))

(defun ia/tab-bar-modified--sanitize-history ()
  "Strip text properties and natively deduplicate the history list.
Prevents 'ghost' duplicates where visually identical strings fail `equal`
comparisons due to hidden text properties."
  (when ia/tab-bar-modified--history
    (setq ia/tab-bar-modified--history
          (delete-dups (mapcar #'substring-no-properties ia/tab-bar-modified--history)))))

(defun ia/tab-bar-modified--get-candidates (&optional force-history)
  "Generate a static snapshot alist for stable previews."
  (let* ((tabs (tab-bar-tabs))
         (active-names nil)
         (candidates nil)
         (name-counts (make-hash-table :test 'equal)))

    (cl-loop for tab in tabs
             for idx from 1
             for raw-name = (alist-get 'name tab)
             for data = (ia/tab-bar-modified--get-tab-data tab)
             for buffer = (nth 0 data)
             for win-count = (nth 1 data)
             for group = (nth 2 data)
             for count = (gethash raw-name name-counts 0)
             for unique-name = (if (= count 0) raw-name (format "%s<%d>" raw-name (1+ count)))
             do
             (puthash raw-name (1+ count) name-counts)
             (push raw-name active-names)
             (push (list unique-name idx raw-name buffer win-count group) candidates))
    (setq candidates (nreverse candidates))

    (if (not (or ia/tab-bar-modified-enable-history force-history))
        candidates
      (let ((history-cands nil)
            (seen-history nil))
        (dolist (hist-item ia/tab-bar-modified--history)
          (when (stringp hist-item)
            (unless (or (string= hist-item "")
                        (member hist-item active-names)
                        (member hist-item seen-history))
              (push hist-item seen-history)
              (push (list hist-item nil hist-item nil nil nil) history-cands))))
        (append candidates (nreverse history-cands))))))

(defun ia/tab-bar-modified--build-annotator (candidates)
  "Pre-calculate column widths and return an annotation closure."
  (let ((max-base 0) (max-win 0) (max-grp 0))

    ;; Pass 1: Measure maximum widths for grid alignment
    (dolist (item candidates)
      (let* ((cand (nth 0 item))
             (idx  (nth 1 item))
             (win  (nth 4 item))
             (grp  (nth 5 item))
             (base-w (+ (string-width cand) (if idx (length (format " [%d]" idx)) 9))) ; " (closed)" is 9 chars
             (win-w  (if win (length (format "win:%d" win)) 0))
             (grp-w  (if win (length (format "group:%s" (if (> (length grp) 0) grp "none"))) 0)))
        (setq max-base (max max-base base-w)
              max-win  (max max-win win-w)
              max-grp  (max max-grp grp-w))))

    ;; Pass 2: Return the closure that physically builds the string
    (lambda (cand)
      (let* ((match (assoc-string cand candidates))
             (idx   (nth 1 match))
             (buf   (nth 3 match))
             (win   (nth 4 match))
             (grp   (nth 5 match))
             (i-str (if idx (format " [%d]" idx) " (closed)"))
             (i-face (if idx 'ia/tab-bar-modified-index-face 'ia/tab-bar-modified-closed-face))
             (base-w (+ (string-width cand) (string-width i-str)))
             (pad-base (make-string (max 1 (+ (- max-base base-w) 4)) ?\s))
             (suffix (concat (propertize i-str 'face i-face) pad-base)))

        (when (and ia/tab-bar-modified-show-extra-states win)
          (let* ((w-str (format "win:%d" win))
                 (g-str (format "group:%s" (if (> (length grp) 0) grp "none")))
                 (w-pad (make-string (max 1 (+ (- max-win (length w-str)) 2)) ?\s))
                 (g-pad (make-string (max 1 (+ (- max-grp (length g-str)) 2)) ?\s)))
            (setq suffix (concat suffix
                                 (propertize w-str 'face 'ia/tab-bar-modified-window-face) w-pad
                                 (propertize g-str 'face 'ia/tab-bar-modified-group-face) g-pad
                                 (propertize buf 'face 'ia/tab-bar-modified-buffer-face)))))

        ;; Returning a 3-element list maps natively to Consult and Affixation UI
        (list cand "" suffix)))))

;; --- Shared Execution Utilities ---

(defun ia/tab-bar-modified--purge-child-frames ()
  "Forcefully delete ALL child frames (visible or invisible).
[TRAP WARNING]: Wayland/PGTK Deadlock Prevention.
When `current-window-configuration` is called, it captures invisible Corfu
frames. Restoring that state during active minibuffer blocks deadlocks the
PGTK display server. This aggressively sanitizes the environment first."
  (when (fboundp 'corfu-quit)
    (ignore-errors (corfu-quit)))
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
  "Execute tab switch or creation based on the SELECTED-KEY from the prompt."
  (when (and selected-key (not (string= selected-key "")))
    (let* ((match (assoc-string selected-key candidates))
           (target-idx (nth 1 match))
           (target-name (if match (nth 2 match) selected-key)))

      (if target-idx
          (tab-bar-select-tab target-idx)
        (tab-bar-new-tab)
        (when ia/tab-bar-modified-sanitize-new-tab
          (set-window-prev-buffers (selected-window) nil)
          (set-window-next-buffers (selected-window) nil))
        (tab-bar-rename-tab target-name)))))

(defun ia/tab-bar-modified--build-state (candidates orig-index orig-tabs orig-wc)
  "Build a compiler-safe state closure for Consult previews."
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

;; --- Interactive Commands ---

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))

  (ia/tab-bar-modified--purge-child-frames)

  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (orig-index (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) orig-index)) candidates)))
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration)))

    (if (null candidates)
        (user-error "No active tabs found")

      (let ((marginalia-annotators (if ia/tab-bar-modified-disable-marginalia nil (bound-and-true-p marginalia-annotators)))
            (history-delete-duplicates t)) ; Force native deduplication
        (ia/tab-bar-modified--execute-switch
         (unwind-protect
             (let ((completion-extra-properties
                    (list :category 'tab
                          :display-sort-function (if ia/tab-bar-modified-sort-function
                                                     (lambda (cands) (funcall ia/tab-bar-modified-sort-function cands candidates))
                                                   #'identity))))
               (consult--read
                candidates
                :prompt "Switch Workspace (or create new): "
                :default default-cand
                :category 'tab
                :sort nil
                :history (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
                :require-match nil
                :annotate (if ia/tab-bar-modified-disable-marginalia (ia/tab-bar-modified--build-annotator candidates) nil)
                :state (ia/tab-bar-modified--build-state candidates orig-index orig-tabs orig-wc)))
           ;; Unconditional cleanup
           (ia/tab-bar-modified--sanitize-history))
         candidates)))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (ia/tab-bar-modified--purge-child-frames)

  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) current-idx)) candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (let ((history-delete-duplicates t)) ; Force native deduplication
        (ia/tab-bar-modified--execute-switch
         (unwind-protect
             (let ((marginalia-annotators (if ia/tab-bar-modified-disable-marginalia nil (bound-and-true-p marginalia-annotators)))
                   (completion-extra-properties
                    (list :category
                          'tab
                          :display-sort-function
                          (if ia/tab-bar-modified-sort-function
                              (lambda (cands) (funcall ia/tab-bar-modified-sort-function cands candidates))
                            #'identity)
                          :affixation-function
                          (if ia/tab-bar-modified-disable-marginalia
                              (let ((annotator (ia/tab-bar-modified--build-annotator candidates)))
                                (lambda (cands) (mapcar annotator cands)))
                            nil))))
               (completing-read "Switch to tab: "
                                candidates
                                nil nil nil
                                (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
                                default-cand))
           ;; Unconditional cleanup
           (ia/tab-bar-modified--sanitize-history))
         candidates)))))

(defun ia-advice/tab-bar-rename-tab-around (orig-fun &optional name arg)
  "Wrap `tab-bar-rename-tab` to provide rich history completion for tab names."
  (interactive
   (let* ((rich-cands (ia/tab-bar-modified--get-candidates t))
          (filtered-cands nil)
          (plain-cands nil))

     (ia/tab-bar-modified--purge-child-frames)

     (dolist (cand rich-cands)
       (let ((is-active (nth 1 cand)))
         (when (or (and is-active ia/tab-bar-modified-rename-include-active)
                   (and (not is-active) ia/tab-bar-modified-rename-enable-history))
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
                          (if ia/tab-bar-modified-disable-marginalia
                              nil
                            (bound-and-true-p marginalia-annotators)))
                         (completion-extra-properties
                          (list
                           :category
                           'tab
                           :display-sort-function
                           (if ia/tab-bar-modified-sort-function
                               (lambda (cands)
                                 (funcall ia/tab-bar-modified-sort-function cands filtered-cands))
                             #'identity)
                           :affixation-function
                           (if ia/tab-bar-modified-disable-marginalia
                               (let ((annotator (ia/tab-bar-modified--build-annotator filtered-cands)))
                                 `(lambda (cands)
                                   (mapcar ,annotator cands)))
                             nil)
                           )))
                     (completing-read
                      "New name for tab (leave blank for default name): "
                      plain-cands nil nil nil
                      (and ia/tab-bar-modified-rename-enable-history 'ia/tab-bar-modified--history)))
                 ;; Unconditional cleanup
                 (ia/tab-bar-modified--sanitize-history))))
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

(define-minor-mode ia/tab-bar-modified-consult-mode
  "Global minor mode to manage index-safe tab switching and built-in overrides."
  :global t
  :group 'ia/tab-bar-modified
  :keymap (make-sparse-keymap)
  (if ia/tab-bar-modified-consult-mode
      (progn
        (advice-add 'tab-bar-switch-to-tab :override 'ia-advice/tab-bar-switch-indexed-override)
        (advice-add 'tab-bar-rename-tab :around 'ia-advice/tab-bar-rename-tab-around))
    (advice-remove 'tab-bar-switch-to-tab 'ia-advice/tab-bar-switch-indexed-override)
    (advice-remove 'tab-bar-rename-tab 'ia-advice/tab-bar-rename-tab-around)))

(provide 'ia-tab-bar-modified-consult)

;;; ia-tab-bar-modified-consult.el ends here
