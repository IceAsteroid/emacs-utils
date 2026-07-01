;;; ia-tab-bar-modified-consult.el --- tab-bar-mode modified & consult features for tab-bar-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;; A highly optimized, index-safe tab bar management module.
;; Provides native UI enhancements, Consult integration, and history tracking.

(require 'cl-lib)

;; Pacify the byte-compiler for Marginalia integration
(defvar marginalia-mode)
(defvar marginalia-annotators)
(defvar marginalia-annotator-registry)

;;; Code:

(defgroup ia/tab-bar-modified nil
  "Customizations for index-safe tab bar management."
  :group 'tab-bar)

(defcustom ia/tab-bar-modified-enable-history t
  "Non-nil to enable history tracking and display closed tabs as candidates."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-sanitize-new-tab nil
  "Non-nil to not bring previous selected buffer window to the new tab.
As to not show the buffer window in the tab line header when
`global-tab-line-mode' is enabled."
  :type 'boolean
  :group 'ia/tab-bar-modified)

(defcustom ia/tab-bar-modified-disable-marginalia t
  "Non-nil to natively suppress Marginalia during tab switching.
When t, uses the custom native UI without Marginalia hijacking the category."
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
  "Function to sort completion candidates before rendering.
It takes two arguments: CANDS (list of current candidate strings)
and ALIST (the rich candidate data structure).
Set to nil to let the completion frontend (like Vertico/Consult) handle sorting."
  :type '(choice (const :tag "Active Tabs First" ia/tab-bar-modified-sort-active-first)
                 (const :tag "Let Frontend Sort" nil)
                 (function :tag "Custom Sort Function"))
  :group 'ia/tab-bar-modified)

(defvar ia/tab-bar-modified--history nil
  "Tracked history list containing raw selection entries.
Shared history for `tab-switch', it aliases `tab-bar-switch-to-tab' and
`ia/consult-tab-switch'.")

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
  "Recursively extract only currently visible buffers from a window state WS.
Uses an omni-directional crawl to completely ignore Emacs's irregular
structural nodes and dotted pairs."
  (let ((buffers nil))
    (cl-labels ((walk (node)
                  (cond
                   ;; Found the exact signature of an active buffer: (buffer "name" ...)
                   ((and (consp node)
                         (eq (car node) 'buffer)
                         (stringp (cadr node)))
                    (push (cadr node) buffers))
                   
                   ;; Otherwise, if it's any cons cell, keep digging.
                   ;; By walking `car` then `cdr`, we are 100% immune to dotted pair crashes.
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
                  buf-str (if bufs
                              (mapconcat #'identity bufs " ")
                            "unknown")))
        (setq win-count 0
              buf-str "unknown")))

    (list buf-str win-count group)))

(defun ia/tab-bar-modified--get-candidates (&optional force-history)
  "Generate a static snapshot alist for stable previews.
If FORCE-HISTORY is non-nil, include closed history tabs even if globally disabled."
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

(defun ia/tab-bar-modified--affix-candidates (cands candidates-alist)
  "Inject right-side indices and compute perfect grid alignments for extra states."
  (let* ((max-base 0) (max-win 0) (max-grp 0)
         (items (mapcar (lambda (cand)
                          (let* ((match (assoc-string cand candidates-alist))
                                 (idx (nth 1 match))
                                 (buffer (nth 3 match))
                                 (win-count (nth 4 match))
                                 (group (nth 5 match))
                                 (index-plain (if idx (format " [%d]" idx) " (closed)"))
                                 (base-width (+ (string-width cand) (string-width index-plain)))

                                 (win-plain (if win-count (format "win:%d" win-count) ""))
                                 (grp-plain (if win-count
                                                (format "group:%s"
                                                        (if (and (stringp group) (> (length group) 0))
                                                            group "none"))
                                              ""))

                                 (index-prop (if idx
                                                 (propertize index-plain 'face 'ia/tab-bar-modified-index-face)
                                               (propertize index-plain 'face 'ia/tab-bar-modified-closed-face))))

                            (setq max-base (max max-base base-width)
                                  max-win  (max max-win (string-width win-plain))
                                  max-grp  (max max-grp (string-width grp-plain)))

                            (list cand index-prop (or buffer "unknown") win-plain grp-plain base-width)))
                        cands)))

    (mapcar (lambda (item)
              (let* ((cand (nth 0 item))
                     (index-prop (nth 1 item))
                     (buffer (nth 2 item))
                     (win-plain (nth 3 item))
                     (grp-plain (nth 4 item))
                     (base-width (nth 5 item))
                     ;; Mathematically force positive padding safely
                     (pad-len (max 1 (+ (- max-base base-width) 4)))
                     (align-space (make-string pad-len ?\s))
                     (suffix (concat index-prop align-space)))

                (when (and ia/tab-bar-modified-show-extra-states (> (length win-plain) 0))
                  (let* ((win-pad-len (max 1 (+ (- max-win (string-width win-plain)) 2)))
                         (grp-pad-len (max 1 (+ (- max-grp (string-width grp-plain)) 2)))
                         (win-pad (make-string win-pad-len ?\s))
                         (grp-pad (make-string grp-pad-len ?\s))
                         (win-str (propertize win-plain 'face 'ia/tab-bar-modified-window-face))
                         (grp-str (propertize grp-plain 'face 'ia/tab-bar-modified-group-face))
                         (buf-str (propertize buffer 'face 'ia/tab-bar-modified-buffer-face)))

                    (setq suffix (concat suffix win-str win-pad grp-str grp-pad buf-str))))

                (list cand "" suffix)))
            items)))

;; --- Shared Execution & Setup Utilities ---

(defmacro ia/tab-bar-modified--with-thrash-protection (&rest body)
  "Execute BODY while freezing the active minibuffer height."
  `(let* ((mini (active-minibuffer-window))
          (h (and mini (window-height mini))))
     ,@body
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

(defun ia/tab-bar-modified--run-with-completion-setup (candidates prompt-fn)
  "Execute PROMPT-FN (a closure) with Marginalia gagging and native properties bound."
  (let* ((marginalia-mode (if ia/tab-bar-modified-disable-marginalia nil (bound-and-true-p marginalia-mode)))
         (marginalia-annotators (if ia/tab-bar-modified-disable-marginalia nil (bound-and-true-p marginalia-annotators)))
         (marginalia-annotator-registry (if ia/tab-bar-modified-disable-marginalia nil (bound-and-true-p marginalia-annotator-registry)))
         (completion-extra-properties
          (append
           `(:category tab
             :affixation-function
             ,(lambda (cands) (ia/tab-bar-modified--affix-candidates cands candidates)))
           (when ia/tab-bar-modified-sort-function
             `(:display-sort-function
               ,(lambda (cands) (funcall ia/tab-bar-modified-sort-function cands candidates)))))))
    (funcall prompt-fn)))

;; --- Interactive Commands ---

(defun ia/consult-tab-switch ()
  "Switch tab-bar tabs using live previews, or create a new tab if no match."
  (interactive)
  (unless tab-bar-mode
    (user-error "Tab-bar-mode is not active"))
  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (orig-index (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) orig-index)) candidates)))
         ;; SNAPSHOT STATE: Protect against preview corruption!
         (orig-tabs (copy-tree (frame-parameter nil 'tabs)))
         (orig-wc (current-window-configuration)))

    (if (null candidates)
        (user-error "No active tabs found")
      (ia/tab-bar-modified--execute-switch
       (ia/tab-bar-modified--run-with-completion-setup candidates
         (lambda ()
           (consult--read
            candidates
            :prompt "Switch Workspace (or create new): "
            :default default-cand
            :category 'tab
            :sort nil
            :history (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
            :require-match nil
            :state (lambda (action cand)
                     (cond
                      ;; PREVIEW VALID CANDIDATE
                      ((and (eq action 'preview) cand)
                       (let* ((match (assoc-string cand candidates))
                              (target-idx (nth 1 match)))
                         (when target-idx
                           (ia/tab-bar-modified--with-thrash-protection
                            (tab-bar-select-tab target-idx)))))
                      
                      ;; PREVIEW NIL (User typed a typo, restore preview state to origin)
                      ((and (eq action 'preview) (not cand))
                       (ia/tab-bar-modified--with-thrash-protection
                        (tab-bar-select-tab orig-index)))
                      
                      ;; FINAL SELECTION OR ABORT
                      ((eq action 'return)
                       ;; TOTAL ROLLBACK: Restore Pristine Tabs and Windows
                       (set-frame-parameter nil 'tabs orig-tabs)
                       (set-window-configuration orig-wc)
                       (tab-bar-select-tab orig-index)))))))
       candidates))))

(defun ia-advice/tab-bar-switch-indexed-override ()
  "Collision-free override for the built-in `tab-bar-switch-to-tab` command."
  (interactive)
  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (current-idx (1+ (tab-bar--current-tab-index)))
         (default-cand (car (cl-find-if (lambda (pair) (eq (nth 1 pair) current-idx)) candidates))))
    (if (null candidates)
        (user-error "No active tabs found")
      (ia/tab-bar-modified--execute-switch
       (ia/tab-bar-modified--run-with-completion-setup candidates
         (lambda ()
           (completing-read "Switch to tab: "
                            candidates
                            nil nil nil
                            (and ia/tab-bar-modified-enable-history 'ia/tab-bar-modified--history)
                            default-cand)))
       candidates))))

(defun ia-advice/tab-bar-rename-tab-around (orig-fun &optional name arg)
  "Wrap `tab-bar-rename-tab` to provide rich history completion for tab names."
  (interactive
   (let* ((rich-cands (ia/tab-bar-modified--get-candidates t))
          (filtered-cands nil)
          (plain-cands nil))

     (dolist (cand rich-cands)
       (let ((is-active (nth 1 cand)))
         (when (or (and is-active ia/tab-bar-modified-rename-include-active)
                   (and (not is-active) ia/tab-bar-modified-rename-enable-history))
           (push cand filtered-cands)
           (push (car cand) plain-cands))))

     (setq filtered-cands (nreverse filtered-cands))
     (setq plain-cands (nreverse plain-cands))

     (let* ((selected-key
             (if (null plain-cands)
                 (read-string "New name for tab (leave blank for default name): ")
               (ia/tab-bar-modified--run-with-completion-setup filtered-cands
                 (lambda ()
                   (completing-read
                    "New name for tab (leave blank for default name): "
                    plain-cands nil nil nil
                    (and ia/tab-bar-modified-rename-enable-history 'ia/tab-bar-modified--history))))))
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
