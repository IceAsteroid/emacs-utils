;;; ia-fix-man-osc8-hyperlink-81240.el --- Fix raw OSC 8 escapes in Man-mode  -*- lexical-binding: t; -*-

;;; Commentary:
;; Workaround for Emacs bug #81240: raw OSC 8 hyperlink escape
;; sequences appear literally in Man-mode buffers (e.g. `M-x man
;; mktemp(1)'), making the text hard to read.
;;
;; Bug: https://debbugs.gnu.org/81240
;; Fix: commit e13fb667a217 "Support OSC 8 hyperlinks in man pages"
;; (Emacs 32 / master).  Not backported to 31, so the workaround runs
;; on versions below 32.
;;
;; The workaround manually converts leftover raw OSC 8 escape
;; sequences into clickable buttons after Man-mode finishes building
;; the buffer.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/man-osc8-hyperlink-81240 t
  (defun ia-fix/man-osc8-hyperlink-81240 ()
    "Manually convert leftover raw OSC 8 escape sequences into clickable buttons."
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char (point-min))
        ;; Matches: ESC ] 8 ; ; <URL> ESC \ <TEXT> ESC ] 8 ; ; ESC \
        (while (re-search-forward "\e\\]8;;\\([^\e]*\\)\e\\\\\\(.*?\\)\e\\]8;;\e\\\\" nil t)
          (let ((url (match-string 1))
                (text (match-string 2)))
            ;; Replace the entire raw sequence with just the readable text
            (replace-match text)
            ;; Turn that text into a clickable link
            (make-text-button (match-beginning 0) (match-end 0)
                              'help-echo url
                              'action (lambda (_) (browse-url url))
                              'follow-link t))))))
  ;; Version 31 still has this problem persisted, so change it to run
  ;; if lesser than version 32.
  (if (< emacs-major-version 32)
      ;; Run this sweep right after Man-mode finishes building the buffer
      (add-hook 'Man-cooked-hook #'ia-fix/man-osc8-hyperlink-81240)
    (message "Emacs version now is >= 32. `ia-fix/man-osc8-hyperlink-81240' won't run.")))

(provide 'ia-fix-man-osc8-hyperlink-81240)

;;; ia-fix-man-osc8-hyperlink-81240.el ends here
