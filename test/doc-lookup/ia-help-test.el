;;; ia-help-test.el --- Tests for the help utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the help mode hook and the customization status line.

;;; Code:

(require 'buttercup)
(require 'ia-help-modified)

(describe "ia/help-modified-mode"
  (after-each
    (ia/help-modified-mode -1)
    (customize-set-variable 'ia/help-modified-customizable-status nil))
  (it "adds the status hook when the mode and option are on"
    (customize-set-variable 'ia/help-modified-customizable-status t)
    (ia/help-modified-mode 1)
    (expect (memq 'ia/help-modified-insert-customizable-status
                  help-fns-describe-variable-functions)
            :to-be-truthy))
  (it "removes the status hook when the mode is off"
    (customize-set-variable 'ia/help-modified-customizable-status t)
    (ia/help-modified-mode 1)
    (ia/help-modified-mode -1)
    (expect (memq 'ia/help-modified-insert-customizable-status
                  help-fns-describe-variable-functions)
            :to-be nil)))

(describe "ia/help-modified-insert-customizable-status"
  (it "inserts the customization status below the header"
    (with-temp-buffer
      (insert "Header\n\nDocstring")
      (let ((standard-output (current-buffer)))
        (ia/help-modified-insert-customizable-status
         'ia/help-modified-customizable-status))
      (expect (buffer-string) :to-match "User customizable: Yes"))))

;;; ia-help-test.el ends here
