;;; ia-buffer-utility.el --- Small snippets for buffer operations  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

;;; Code:

(defun ia/count-total-lines ()
  "Like `count-lines-page', but count for all lines(logically) in a buffer."
  (interactive)
  (save-restriction
    (widen)
    (let ((total (count-lines (point-min) (point-max)))
          (before (count-lines (point-min) (point)))
          (after (count-lines (point) (point-max))))
      (message (ngettext "Buffer has total %d line (%d + %d)"
                         "Buffer has total %d lines (%d + %d)"
                         total)
               total before after))))

(defun ia/mark-things-at-point ()
  "Mark symbol at point.
If repeated, expand to sexp, then list, then line, then defun."
  (interactive)
  (if (and (eq last-command this-command) (use-region-p))
      ;; -- EXPANSION PHASE --
      ;; Define a hierarchy of things to expand into
      (let ((hierarchy '(sexp list line defun buffer))
            (rb (region-beginning))
            (re (region-end))
            (expanded nil))
        (dolist (thing hierarchy)
          (unless expanded
            (let ((bounds (bounds-of-thing-at-point thing)))
              ;; Check if the new bounds are actually larger than current region
              (when (and bounds
                         (or (< (car bounds) rb)
                             (> (cdr bounds) re)))
                (goto-char (car bounds))
                (set-mark (cdr bounds))
                (setq expanded t)
                (message "Expanded to %s" thing))))))
    ;; -- INITIAL PHASE --
    ;; Just mark the symbol
    (when-let ((b (bounds-of-thing-at-point 'symbol)))
      (goto-char (car b))
      (set-mark (cdr b))
      (message "Marked symbol"))))

(provide 'ia-buffer-utility)

;;; ia-buffer-utility.el ends here
