;;; ia-fix-gt-treesit-hang-82.el --- Workaround gt.el hang in tree-sitter modes  -*- lexical-binding: t; -*-

;;; Commentary:
;; Workaround for gt.el issue #82: `gt-translate' hangs with 100% CPU
;; usage in tree-sitter major modes (e.g. `zig-ts-mode',
;; `bash-ts-mode') when translating a selected symbol.
;;
;; Issue: https://github.com/lorniu/gt.el/issues/82
;;
;; Cause: `gt-pick-items-by-thing' narrows the buffer to the selection
;; and repeatedly calls `gt-forward-thing' -> `forward-thing' ->
;; `forward-sentence'.  In Emacs 30 tree-sitter modes,
;; `forward-sentence-function' is `treesit-forward-sentence', which can
;; return nil WITHOUT moving point when the buffer is narrowed to a
;; region that contains no matching sentence node (a bare symbol).
;; `gt-forward-thing' then returns nil, the pick loop never advances and
;; spins forever.
;;
;; The issue was closed upstream pointing to a bug-gnu-emacs thread, but
;; as of Emacs 30/31 the hang persists, so the advice below is still
;; needed.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/gt-treesit-hang-82 t
  (defun ia-fix/gt-treesit-hang-82-ensure-progress (orig thing mode)
    "Around advice for `gt-forward-thing'.

`gt-forward-thing' can return nil without moving point when
`forward-sentence-function' is `treesit-forward-sentence' (Emacs 30
tree-sitter major modes) and the buffer is narrowed to a region with no
sentence node, making `gt-pick-items-by-thing' spin in an infinite loop.
When the original fails to move point, consume the rest of the
accessible region like `forward-sentence-default-function' does, so the
pick loop terminates and returns the same result as in non-tree-sitter
modes."
    (let ((pt (point)))
      (or (funcall orig thing mode)
          (when (= (point) pt)
            (let ((end (point-max)))
              (goto-char end)
              (cons pt end))))))
  ;; `gt-core' is loaded on demand by `gt', so install the advice only
  ;; after it becomes available.
  (with-eval-after-load 'gt-core
    (advice-add 'gt-forward-thing :around #'ia-fix/gt-treesit-hang-82-ensure-progress)))

(provide 'ia-fix-gt-treesit-hang-82)

;;; ia-fix-gt-treesit-hang-82.el ends here
