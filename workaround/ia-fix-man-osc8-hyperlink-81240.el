;;; ia-fix-man.el --- Fix Emacs man glitches  -*- lexical-binding: t; -*-

;;; Commentary:
;;

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/man-hyprlink t
  (defun ia-fix/man-osc8-hyperlinks ()
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
  (if (< emacs-major-version 31)
      ;; Run this sweep right after Man-mode finishes building the buffer
      (add-hook 'Man-cooked-hook #'ia-fix/man-osc8-hyperlinks)
    (message "Emacs version now is greater than 30.x. `ia-fix/man-hyprlink' won't run.")))

(provide 'ia-fix-man)

;;; ia-fix-man.el ends here
