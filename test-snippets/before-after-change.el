;;; before-after-change.el ---

;;; Commentary:
;;

;;; Code

;;;; Before and after buffer change
;; the len is the length of the point at before and after the change. Length is 
;; 1. Define the before-change function (2 arguments)
(defun ia/test-before-change (beg end)
  (message "BEFORE change -> beg: %d, end: %d" beg end))
;; 2. Define the after-change function (3 arguments)
(defun ia/test-after-change (beg end len)
  (message "AFTER change  -> beg: %d, end: %d, len: %d" beg end len))
;; 3. Add them locally to the current buffer
(add-hook 'before-change-functions #'ia/test-before-change nil t)
(add-hook 'after-change-functions #'ia/test-after-change nil t)


;;;; Overlays
;; Test whether remove-overlays / delete-overlay invoke modification-hooks.
;; Conclusion: Calling API to remove overlays will not trigger hooks.
(defun ia-overly-hook-test ()
  (interactive)
  (forward-line 1)
  (insert "Testing remove-overlays...")
  (defvar-local overlay-test-ov nil)
  (let ((ov (make-overlay (line-beginning-position) (line-end-position)))
        (hook (list (lambda (&rest _)
                      ;; (cl-incf overlay-test-count)
                      (message "hook triggered."))
                    )))
    (setq overlay-test-ov ov)
    (overlay-put ov 'modification-hooks hook)
    (overlay-put ov 'evaporate t))
  ;; Open the messages buffer to see the results
  (pop-to-buffer "*Messages*"))
(defun ia-overlay-hook-test-delete ()
  (interactive)
  (delete-overlay overlay-test-ov)
  (kill-local-variable 'overlay-test-ov))



(provide 'before-after-change)

;;; before-after-change.el ends here
