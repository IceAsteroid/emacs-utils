;;; ia-buffer-utility.el --- Small snippets for buffer operations  -*- lexical-binding: t; -*-

;;; Commentary:
;;

;;; Code:

(defgroup ia/buffer-utility nil
  "Customizations for buffer operations and editing utilities."
  :group 'editing)

(defcustom ia/token-delimiter-chars "(){}[]'\"`_"
  "Characters treated as single tokens by token-aware commands.

A token is consecutive alphanumeric characters, consecutive identical
characters listed here, or consecutive other punctuation characters.

Consecutive identical characters listed here are killed as a single
token, so with `_' listed, `foo__bar' is `foo', `__' and `bar';
different adjacent delimiters are killed one at a time, so `foo([bar' is
`foo', `[', `(' and `bar'.  Unlisted punctuation such as `:', `;' or `-'
is killed as a single token, so `foo::bar' is `foo', `::' and `bar'.

Currently consumed by `ia/backward-kill-word' and `ia/kill-word'."
  :group 'ia/buffer-utility
  :type 'string
  :safe #'stringp)

(defcustom ia/tab-whitespace-as-single-token nil
  "When non-nil, treat a tab directly at point as a single token.

With this enabled, `ia/backward-kill-word' kills a tab before point
alone, and `ia/kill-word' kills a tab after point alone, instead of
together with the adjacent token."
  :group 'ia/buffer-utility
  :type 'boolean
  :safe #'booleanp)

(defun ia/count-total-lines ()
  "Like `count-lines-page', but count every logical line in the buffer."
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
  "Mark the symbol at point.
If repeated, expand to sexp, then list, then line, then defun, and
continue expand to any outer one if any, then the whole buffer."
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

(defun ia/backward-kill-word ()
  "Enhanced version of `backward-kill-word'.

If two or more whitespace characters before point, only those
whitespace characters are killed.  If one whitespace character or none,
the whitespace (if any) together with the token immediately before it
is treated as one token, so a single call deletes both.  Newlines count
as whitespace.  See `ia/token-delimiter-chars' for what counts as a
token.

When `ia/tab-whitespace-as-single-token' is non-nil, a tab directly
before point is treated as its own token: it is killed alone, not
together with the token before it.

Kills via `kill-region', so the text lands in the `kill-ring' and can
be yanked back.  Repeated kills in a row are kept together as one
entry, in the original order, so yanking restores the killed text as it
was."
  (interactive)
  (if (use-region-p)
      (kill-region (region-beginning) (region-end))
    (let ((p (point)))
      (unless (bobp)
        (cond
         ;; A tab whether counts as a single token to kill when before
         ;; a token.
         ((and ia/tab-whitespace-as-single-token (eq (char-before) ?\t))
          (backward-char))
         ;; 2+ whitespace chars: kill just the whitespace gap.
         ((>= (abs (skip-chars-backward "[:space:]")) 2) t)
         ;; One or none: also kill the token before point.
         ((bobp) nil)
         ((> (abs (skip-chars-backward ia/token-delimiter-chars (1- (point)))) 0)
          ;; Identical adjacent delimiters form one token (e.g. `((' or
          ;; `__'), so keep skipping the same delimiter char.
          (skip-chars-backward (string (char-after)))
          t)
         ((> (abs (skip-chars-backward "[:alnum:]")) 0) t)
         (t (skip-chars-backward (concat "^[:alnum:][:space:]" ia/token-delimiter-chars)))))
      ;; Pass (larger, smaller) so repeated kills accumulate in the order
      ;; the text appeared (`kill-region' prepends when end < beg).
      (kill-region p (point)))))

(defun ia/kill-word ()
  "Enhanced version of `kill-word'.

Like `ia/backward-kill-word', but kills forward: the whitespace and the
token are taken after point instead of before it.

See the docstring of `ia/backward-kill-word' for details."
  (interactive)
  (if (use-region-p)
      (kill-region (region-beginning) (region-end))
    (let ((p (point)))
      (unless (eobp)
        (cond
         ;; A tab whether counts as a single token to kill when before
         ;; a token.
         ((and ia/tab-whitespace-as-single-token (eq (char-after) ?\t))
          (forward-char))
         ;; 2+ whitespace chars: kill just the whitespace gap.
         ((>= (skip-chars-forward "[:space:]") 2) t)
         ;; One or none: also kill the token after point.
         ((eobp) nil)
         ((> (skip-chars-forward ia/token-delimiter-chars (1+ (point))) 0)
          ;; Identical adjacent delimiters form one token (e.g. `((' or
          ;; `__'), so keep skipping the same delimiter char.
          (skip-chars-forward (string (char-before)))
          t)
         ((> (skip-chars-forward "[:alnum:]") 0) t)
         (t (skip-chars-forward (concat "^[:alnum:][:space:]" ia/token-delimiter-chars)))))
      (kill-region p (point)))))

(provide 'ia-buffer-utility)

;;; ia-buffer-utility.el ends here
