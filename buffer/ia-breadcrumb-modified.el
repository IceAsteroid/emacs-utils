;;; ia-breadcrumb-modified.el --- A mode that modified breadcrumb-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;; Added smooth truncation without truncating each note to one
;; character immediately.

;; Added a variable `my-breadcrumb-ancestor-min-length' and its
;; feature that preserve a minimum number of characters when window
;; width is not enought and breadcrumb starts truncation.

;;; TODO
;; 1. Add a variable `breadcrumb-ancestor-truncate-direction' to
;; truncate from left or right.
;; 2. Inspect and understand the code, and then PR this to upstream.

(require 'breadcrumb)

;;; Code:

(defvar my-breadcrumb-ancestor-min-length 3
  "The minimum character limit for ancestor nodes before they are dropped entirely.")

(defun ia/bc--summerice-overide (crumbs cutoff separator)
  "Override `breadcrumb--summarize` to enforce a minimum length and drop ancestors if they don't fit."
  (condition-case err
      (let* (;; FIX: Force cutoff to be a strict integer immediately to avoid floating-point math issues
             (cutoff (truncate cutoff))
             (sep-len (length separator))
             (num-crumbs (length crumbs))
             (total-sep-len (* (max 0 (1- num-crumbs)) sep-len))
             (total-len (+ total-sep-len (cl-reduce #'+ crumbs :key #'length))))

        ;; If the original full string fits perfectly, return it without modification.
        (if (<= total-len cutoff)
            (string-join crumbs separator)

          (let* ((parents (butlast crumbs))
                 (current (car (last crumbs)))
                 (min-len (max 1 my-breadcrumb-ancestor-min-length))
                 ;; 1. Determine how much space the current node minimally needs
                 (current-need (min (length current) min-len))
                 (available-for-parents (- cutoff current-need))
                 (kept-parents nil))

            ;; 2. Work backwards (right-to-left) to drop oldest ancestors that don't fit
            (dolist (p (reverse parents))
              (let ((cost (+ min-len sep-len)))
                (if (>= available-for-parents cost)
                    (progn
                      (push p kept-parents)
                      (setq available-for-parents (- available-for-parents cost)))
                  ;; Stop adding parents the second we run out of room
                  (setq available-for-parents -1))))

            ;; 3. Distribute the remaining space evenly to the parents that survived
            (let* ((num-kept (length kept-parents))
                   (new-total-sep-len (* num-kept sep-len))
                   (min-kept-space (* num-kept min-len))
                   (current-max (max 1 (- cutoff new-total-sep-len min-kept-space)))
                   (current-len (min (length current) current-max))
                   (remaining-space (max 0 (- cutoff new-total-sep-len current-len)))
                   ;; FIX: Ensure fair-share is also truncated to prevent division floats
                   (fair-share (truncate (if (> num-kept 0) (/ remaining-space num-kept) 0)))
                   (allowed-parent-len (max min-len fair-share)))

              (string-join
               (append
                (mapcar (lambda (p)
                          (let ((l (min (length p) allowed-parent-len)))
                            (substring p 0 l)))
                        kept-parents)
                (list (substring current 0 current-len)))
               separator)))))
    ;; Fallback: Print error string instead of silently blanking out the header line
    (error (format "Breadcrumb Error: %s" (error-message-string err)))))

;;;###autoload
(define-minor-mode ia/breadcrumb-modified-mode
  "A local minor mode that modifies `breadcrumb-mode'."
  :group 'breadcrumb
  :global t
  (if ia/breadcrumb-modified-mode
       (advice-add 'breadcrumb--summarize :override 'ia/bc--summerice-overide)
    ;; Clean up and exit.
    (advice-remove 'breadcrumb--summarize 'ia/bc--summerice-overide)))

(provide 'ia-breadcrumb-modified)

;;; ia-breadcrumb-modified.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("ia/bc-" . "ia/breadcrumb-"))
;; End:
