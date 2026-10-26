;;; ia-org-test.el --- Tests for the Org utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the item helpers, the emphasis toggle, the results advice
;; and the indent advice.

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'org)
(require 'ob-core)
(require 'ia-org-utility)
(require 'ia-org-item-toggle)
(require 'ia-org-indent-modified)

(defmacro ia/test-with-org-buffer (text &rest body)
  "Insert TEXT in a temp Org buffer and evaluate BODY."
  `(with-temp-buffer
     (insert ,text)
     (org-mode)
     (goto-char (point-min))
     ,@body))

(describe "ia/org-item-nesting-level"
  (it "returns the level of a first-level item and a nested item"
    (ia/test-with-org-buffer "- one\n  - two\n"
      (let ((items (org-element-map (org-element-parse-buffer)
                     'item #'identity)))
        (expect (mapcar #'ia/org-item-nesting-level items)
                :to-equal '(1 2))))))

(describe "ia/org-item-map"
  (it "visits every item in order"
    (ia/test-with-org-buffer "- one\n  - two\n"
      (let (levels)
        (ia/org-item-map
         (lambda (item) (push (ia/org-item-nesting-level item) levels)))
        (expect (nreverse levels) :to-equal '(1 2)))))
  (it "visits only the items at or above the level"
    (ia/test-with-org-buffer "- one\n  - two\n"
      (let (levels)
        (ia/org-item-map
         (lambda (item) (push (ia/org-item-nesting-level item) levels))
         nil nil 1)
        (expect (nreverse levels) :to-equal '(1))))))

(describe "ia/org-toggle-emphasis-display"
  (it "toggles the buffer-local emphasis marker display"
    (ia/test-with-org-buffer "* Heading\n"
      (setq-local org-hide-emphasis-markers nil)
      (ia/org-toggle-emphasis-display)
      (expect org-hide-emphasis-markers :to-be t)
      (ia/org-toggle-emphasis-display)
      (expect org-hide-emphasis-markers :to-be nil))))

(describe "ia/advice/org-babel-remove-blank-line-before-results"
  (it "removes the blank line before a results block"
    (ia/test-with-org-buffer "src\n\n#+RESULTS:\n"
      (forward-line 2)
      (ia-advice/org-babel-remove-blank-line-before-results nil nil)
      (expect (buffer-string) :to-equal "src\n#+RESULTS:\n"))))

(describe "ia/org-remove-blank-line-before-results-mode"
  (it "installs and removes the results advice"
    (unwind-protect
        (progn
          (ia/org-remove-blank-line-before-results-mode 1)
          (expect (advice-member-p
                   'ia-advice/org-babel-remove-blank-line-before-results
                   'org-babel--insert-results-keyword)
                  :to-be-truthy)
          (ia/org-remove-blank-line-before-results-mode -1)
          (expect (advice-member-p
                   'ia-advice/org-babel-remove-blank-line-before-results
                   'org-babel--insert-results-keyword)
                  :to-be nil))
      (ia/org-remove-blank-line-before-results-mode -1))))

(describe "ia/org-indent-modified-mode"
  (it "installs and removes the indent advice"
    (cl-letf (((symbol-function 'ia/org-indent-modified--refresh-buffers)
               #'ignore))
      (unwind-protect
          (progn
            (ia/org-indent-modified-mode 1)
            (expect (advice-member-p
                     'ia/org-indent-modified-set-line-properties
                     'org-indent-set-line-properties)
                    :to-be-truthy)
            (ia/org-indent-modified-mode -1)
            (expect (advice-member-p
                     'ia/org-indent-modified-set-line-properties
                     'org-indent-set-line-properties)
                    :to-be nil))
        (ia/org-indent-modified-mode -1)))))

;;; ia-org-test.el ends here
