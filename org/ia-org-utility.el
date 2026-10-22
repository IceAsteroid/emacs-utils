;;; ia-org-utility.el --- Small custom snippets for org-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;;

(require 'org)
(require 'org-element)

;;; Code:

(defgroup ia/org-utility nil
  "Additional small snippets for Org mode."
  :group 'org)

(defun ia/org-toggle-emphasis-display ()
  "Fast buffer-wide toggle of `org-hide-emphasis-markers`."
  (interactive)
  (setq-local org-hide-emphasis-markers (not org-hide-emphasis-markers))
  ;; Flushes the font-lock without restarting the entire major mode
  (font-lock-flush)
  (message "Buffer emphasis markers %s."
           (if org-hide-emphasis-markers "hidden" "visible")))

(defun ia/org-redisplay-inline-images-at-block (&optional interactive-p)
  "Refresh inline images around a source block.

Use the block recorded in `org-babel-current-src-block-location',
or the source block at point when that variable is nil.  Do
nothing when there is no block to act on.  When INTERACTIVE-P is
non-nil (set by the interactive spec), signal a `user-error' if
there is no block."
  (interactive "p")
  (let ((block-location (or org-babel-current-src-block-location
                            (and (derived-mode-p 'org-mode)
                                 (org-babel-where-is-src-block-head)))))
    (when (markerp block-location)
      (setq block-location (marker-position block-location)))
    (when (and (not block-location) interactive-p)
      (user-error "Not on a source block"))
    (when block-location
      (save-excursion
        (goto-char block-location)
        (let* ((block-element (org-element-at-point))
               (refresh-end (org-element-end block-element))
               ;; `org-babel-where-is-src-block-result' locates the
               ;; results of the block at point and ignores its INFO
               ;; argument, so no need for `org-babel-get-src-block-info'
               ;; (which would re-process header arguments).
               (results-begin (org-babel-where-is-src-block-result)))
          ;; Include the results section, where the generated image
          ;; link is inserted.
          (when results-begin
            (goto-char results-begin)
            (forward-line 1)        ; skip the #+RESULTS: line
            (skip-chars-forward " \t\r\n")
            (let ((element (org-element-at-point)))
              (when element
                (setq refresh-end (max refresh-end (org-element-end element))))))
          (if (fboundp 'org-link-preview-region)
              ;; `org-link-preview-region' introduced in Org version 9.8.
              (org-link-preview-region nil t block-location refresh-end)
            (with-no-warnings
              ;; a deprecated `org-display-inline-images' fallback for Org < 9.8.
              (org-display-inline-images nil t block-location refresh-end))))))))

;; Do not insert a blank line between source block & result block.
;; https://emacs.stackexchange.com/questions/74952/remove-empty-line-between-source-code-and-results-block-in-org-babel-automatical
(defun ia-advice/org-babel-remove-blank-line-before-results (_name _hash)
  "Remove the blank line before the results block.
NAME and HASH are the arguments of
`org-babel--insert-results-keyword'; this advice ignores them."
  (save-excursion
    (forward-line -1)
    (beginning-of-line)
    (when (looking-at-p "\n")
      (kill-line))))

(define-minor-mode ia/org-remove-blank-line-before-results-mode
  "Global minor mode to remove the blank line before results in Org mode.

Invoking `org-ctrl-c-ctrl-c' on a source block that generates a
RESULTS block inserts a blank line between the source block and the
results block; this mode removes the blank line."
  :global t
  :group 'ia/org-utility
  (cond
   (ia/org-remove-blank-line-before-results-mode
    (advice-add 'org-babel--insert-results-keyword :before
                'ia-advice/org-babel-remove-blank-line-before-results))
   (t
    (advice-remove 'org-babel--insert-results-keyword
                   'ia-advice/org-babel-remove-blank-line-before-results))))


(provide 'ia-org-utility)

;;; ia-org-utility.el ends here
