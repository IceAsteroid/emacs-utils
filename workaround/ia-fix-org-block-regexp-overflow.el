;;; ia-fix-org-block-regexp-overflow.el --- Fix org regexp stack overflow on unclosed blocks  -*- lexical-binding: t; -*-

;;; Commentary:
;; Workaround for an org-mode regression that breaks opening org files
;; containing an unclosed (or empty) `#+begin_...' block followed by a
;; large amount of text:
;;
;;   File mode specification error: (error "Stack overflow in regexp matcher")
;;
;; and the buffer cannot be fontified.
;;
;; Root cause: org 9.7 (commit eaf274909, "Consistently allow null
;; character in block and drawer bodies") changed the body-matching
;; part of `org-block-regexp' from the single character class
;; [^\000]+? to the alternation \\(?:.\\|\n\\)+?.  The same change
;; was applied to `org-babel-src-block-regexp' in ob-core.el.  When
;; no matching `#+end_...' exists, the lazy alternation backtracks
;; through every possible split of the remaining buffer, overflowing
;; the regexp engine's backtracking stack.
;;
;; Upstream: reported on the emacs-orgmode mailing list on
;; <2024-06-16> ("[BUG] \"Stack overflow in regexp matcher\" when
;; tangling or noweb referencing large blocks [9.7.4]"), acknowledged
;; by the maintainer, who pointed to commit eaf274909 as the cause:
;; https://list.orgmode.org/DU2P193MB2422253B9729A928D0F569F088CC2@DU2P193MB2422.EURP193.PROD.OUTLOOK.COM
;; The fontification/`org-at-block-p' variant addressed here has no
;; separate bug number.  As of org 9.8.9 (2026-08-15) and current
;; master (2026-08-23) the bad regexps are still present, so this
;; workaround is still needed.
;;
;; The workaround reverts the body-matching alternation to the org
;; 9.6 character-class form [^\000] at load time, preserving every
;; other part of the current regexps.  It self-disables when upstream
;; replaces the alternation: the `string-search' guards below stop
;; matching and leave the variables untouched.  No Emacs version gate
;; is used because the bug is tied to the org library version (org
;; 9.7+), which can be updated independently of Emacs (e.g. from
;; GNU ELPA on older Emacs).
;;
;; Note: this file addresses the block-fontification path via
;; `org-block-regexp' and the tangling/noweb path via
;; `org-babel-src-block-regexp'.  Other regexps touched by the same
;; upstream commit (ob-haskell, org-feed, org-element macros, ox-org)
;; are not patched here; they do not trigger on normal org files.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/org-block-regexp-overflow t
  (defconst ia-fix/org-block-regexp-overflow--bad-body "\\(?:.\\|\n\\)"
    "Literal block-body alternation introduced by org 9.7 (commit eaf274909).
This is the exact group text used in `org-block-regexp' and
`org-babel-src-block-regexp' since org 9.7.")

  (defun ia-fix/org-block-regexp-overflow--fix (regexp)
    "Return REGEXP with the block-body alternation replaced by [^\\000].
Org 9.7+ matches block bodies with \\\\(?:.\\\\|\\n\\\\), which makes the
regexp engine backtrack catastrophically when a `#+begin_...' block
has no matching `#+end_...'.  Replace it with the org 9.6 character
class [^\\000], which matches the same characters in linear time."
    (string-replace ia-fix/org-block-regexp-overflow--bad-body "[^\000]" regexp))

  (with-eval-after-load 'org
    (when (string-search ia-fix/org-block-regexp-overflow--bad-body org-block-regexp)
      (setq org-block-regexp
            (ia-fix/org-block-regexp-overflow--fix org-block-regexp))))

  (with-eval-after-load 'ob-core
    (when (string-search ia-fix/org-block-regexp-overflow--bad-body org-babel-src-block-regexp)
      (setq org-babel-src-block-regexp
            (ia-fix/org-block-regexp-overflow--fix org-babel-src-block-regexp)))))

(provide 'ia-fix-org-block-regexp-overflow)

;;; ia-fix-org-block-regexp-overflow.el ends here
