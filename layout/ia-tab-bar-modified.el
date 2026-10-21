;;; ia-tab-bar-modified.el --- Tab bar data, history and plain reader  -*- lexical-binding: t; -*-

;;; Commentary:
;; The tab bar's candidates, history, sort and annotations, and a plain
;; `completing-read' reader for a tab name.  The consult integration and
;; the tab-switch overrides are in `ia-tab-bar-modified-consult'.

(require 'cl-lib)
(require 'tab-bar)

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
  "Sort CANDS so live tabs dynamically bubble above closed history tabs.
CANDIDATES-ALIST is the alist that `ia/tab-bar-modified--get-candidates'
returns."
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
Prevents duplicates where visually identical strings fail `equal'
comparisons due to hidden text properties."
  (when ia/tab-bar-modified--history
    (setq ia/tab-bar-modified--history
          (delete-dups (mapcar #'substring-no-properties ia/tab-bar-modified--history)))))

(defun ia/tab-bar-modified--get-candidates (&optional force-history)
  "Generate a static snapshot alist for stable previews.
FORCE-HISTORY includes the closed names even when
`ia/tab-bar-modified-enable-history' is nil."
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

(defun ia/tab-bar-modified-read-tab-name (&optional initial)
  "Read a tab name with this package's candidates and history.
The live tabs come first, sorted by `ia/tab-bar-modified-sort-function',
followed by the closed names in `ia/tab-bar-modified--history'.  The
chosen name is returned; selecting the tab or making a new one is the
caller's.  INITIAL is the initial minibuffer input and defaults to the
current tab's name; pass \"\" when the empty name should mean a new tab."
  (let* ((candidates (ia/tab-bar-modified--get-candidates))
         (names (mapcar #'car candidates))
         (current (or initial
                      (car (cl-find-if
                            (lambda (candidate)
                              (eq (nth 1 candidate)
                                  (1+ (tab-bar--current-tab-index))))
                            candidates))))
         (marginalia-annotators
          (if ia/tab-bar-modified-disable-marginalia
              nil
            (bound-and-true-p marginalia-annotators)))
         (history-delete-duplicates t))
    (unwind-protect
        (let ((completion-extra-properties
               (list :category 'tab
                     :display-sort-function
                     (if ia/tab-bar-modified-sort-function
                         (lambda (cands)
                           (funcall ia/tab-bar-modified-sort-function
                                    cands candidates))
                       #'identity)
                     :affixation-function
                     (if ia/tab-bar-modified-disable-marginalia
                         (let ((annotator
                                (ia/tab-bar-modified--build-annotator
                                 candidates)))
                           (lambda (cands) (mapcar annotator cands)))
                       nil))))
          (completing-read
           "Switch Workspace (or create new): "
           names nil nil nil
           (and ia/tab-bar-modified-enable-history
                'ia/tab-bar-modified--history)
           current))
      (ia/tab-bar-modified--sanitize-history))))

(defun ia/tab-bar-modified--build-annotator (candidates)
  "Pre-calculate column widths for CANDIDATES and return an annotation closure."
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

(defun ia/tab-bar-modified-remove-history-item ()
  "Selectively remove a specific item from the tab history."
  (interactive)
  (if (not ia/tab-bar-modified--history)
      (user-error "Tab history is already empty")
    (let ((target (completing-read "Remove history item: "
                                   ia/tab-bar-modified--history
                                   nil t)))
      (setq ia/tab-bar-modified--history
            (delete target ia/tab-bar-modified--history))
      (message "Removed '%s' from tab history." target))))

(defun ia/tab-bar-modified-clear-history ()
  "Completely clear the tab bar history."
  (interactive)
  (setq ia/tab-bar-modified--history nil)
  (message "Tab bar history cleared."))

(provide 'ia-tab-bar-modified)

;;; ia-tab-bar-modified.el ends here
