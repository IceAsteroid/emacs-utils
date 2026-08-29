;;; ia-org-indent-modified.el --- Modified org-indent-mode features  -*- lexical-binding: t; -*-

;; Copyright (C) 2009-2025 Free Software Foundation, Inc.
;;
;; Author: IceAstroid
;; Keywords: outlines, hypermedia, calendar, text
;;
;; This file is not part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A modified version of `org-indent-mode', with all consecutive visual
;; wrapped lines flush left.

;; line-prefix adds indentation on the first line of an element, wrap-prefix
;; adds indentation on its continuous lines, so keeping the latter nil makes
;; only the first line indented, and every wrapped line flush left.

;;; Code:

(require 'org)
(require 'org-indent)

(require 'cl-lib)

(defun ia/org-indent-modified-set-line-properties (level indentation &optional heading)
  "Set prefix properties on current line and move to next one.

LEVEL is the current level of heading.  INDENTATION is the
expected indentation when wrapping line.

When optional argument HEADING is non-nil, assume line is at
a heading.  Moreover, if it is `inlinetask', the first star will
have `org-warning' face.

Like `org-indent-set-line-properties', but always leaves
`wrap-prefix' nil so that consecutive visual wrapped lines are
flush left.  Only the first line of each buffer line is indented,
via `line-prefix'."
  (ignore indentation)
  (let* ((line (aref (pcase heading
                       (`nil org-indent--text-line-prefixes)
                       (`inlinetask org-indent--inlinetask-line-prefixes)
                       (_ org-indent--heading-line-prefixes))
                     level))
         ;; --- Original PART ---
         ;; From `org-indent-set-line-properties' (Emacs 31.1): set
         ;; `wrap-prefix' to the same prefix as `line-prefix', plus the
         ;; indentation of the current line, so continuous (wrapped)
         ;; lines are indented as well:
         ;;
         ;; (wrap
         ;;  (org-add-props
         ;;      (concat line
         ;;              (if heading (concat (make-string level ?*) " ")
         ;;                (make-string indentation ?\s)))
         ;;      nil 'face 'org-indent))
         ;;
         ;; --- MODIFIED PART STARTS HERE ---
         ;; Always keep `wrap-prefix' nil instead.  `line-prefix'
         ;; already indents the first line of each element; leaving
         ;; `wrap-prefix' nil makes every consecutive visual wrapped
         ;; line flush left.
         (wrap nil))
    ;; Add properties down to the next line to indent empty lines.
    (add-text-properties (line-beginning-position) (line-beginning-position 2)
        		 `(line-prefix ,line wrap-prefix ,wrap)))
  (forward-line))

(defun ia/org-indent-modified--refresh-buffers ()
  "Recompute indentation properties in buffers with `org-indent-mode' enabled.

Used when `ia/org-indent-modified-mode' is turned on or off, so the
modified (or restored) `wrap-prefix' behavior takes effect in buffers
that already have `org-indent-mode' enabled.

Relies on `org-indent''s asynchronous agent, the same mechanism
`org-indent-mode' itself uses, so large buffers are refreshed during
idle time instead of blocking."
  (let (buffers)
    ;; `buffer-list' puts the most recently selected buffer first;
    ;; iterate in reverse so that buffer is pushed last and ends up
    ;; first in `org-indent-agentized-buffers', i.e. refreshed first.
    (dolist (buffer (reverse (buffer-list)))
      (with-current-buffer buffer
        (when (and org-indent-mode (derived-mode-p 'org-mode))
          (setq-local org-indent--initial-marker (copy-marker 1))
          (cl-pushnew buffer org-indent-agentized-buffers)
          (push buffer buffers))))
    (when buffers
      ;; The kick below refreshes only one buffer; the idle timer
      ;; processes the rest.  `org-indent-agent-timer' is shared with
      ;; `org-indent-mode', so only start it when none is live -- check
      ;; `timer-idle-list' (idle timers live there; `timerp' can't tell
      ;; a cancelled timer from a live one) -- to avoid duplicate
      ;; agents.
      (unless (memq org-indent-agent-timer timer-idle-list)
        (setq org-indent-agent-timer
              (run-with-idle-timer 0.2 t #'org-indent-initialize-agent)))
      ;; Refresh the current (or first) buffer immediately.
      (org-indent-initialize-agent))))

;;;###autoload
(define-minor-mode ia/org-indent-modified-mode
  "Global minor mode to modify `org-indent-mode' behavior.

When enabled, `org-indent-set-line-properties' is overridden so that
all consecutive visual wrapped lines are flush left, see
`ia/org-indent-modified-set-line-properties'.

Turning this mode on or off also refreshes indentation properties in
all buffers where `org-indent-mode' is enabled, so the change takes
effect immediately."
  :global t
  :group 'org-indent
  (if ia/org-indent-modified-mode
      (advice-add #'org-indent-set-line-properties
                  :override #'ia/org-indent-modified-set-line-properties)
    (advice-remove #'org-indent-set-line-properties
                   #'ia/org-indent-modified-set-line-properties))
  ;; Apply or revert the effect in buffers that already have
  ;; `org-indent-mode' enabled.
  (ia/org-indent-modified--refresh-buffers))

(provide 'ia-org-indent-modified)

;;; ia-org-indent-modified.el ends here
