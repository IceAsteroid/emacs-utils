;;; ia-face-test.el --- Tests for the face utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the variable-pitch predicate.

;;; Code:

(require 'buttercup)
(require 'ia-face-utility)

(describe "ia/variable-pitch-p"
  (it "returns non-nil when the buffer face is variable-pitch"
    (with-temp-buffer
      (setq-local buffer-face-mode t
                  buffer-face-mode-face 'variable-pitch)
      (expect (ia/variable-pitch-p) :to-be-truthy)))
  (it "returns nil when the buffer face is not variable-pitch"
    (with-temp-buffer
      (setq-local buffer-face-mode t
                  buffer-face-mode-face 'fixed-pitch)
      (expect (ia/variable-pitch-p) :to-be nil)))
  (it "returns nil when buffer-face-mode is off"
    (with-temp-buffer
      (setq-local buffer-face-mode nil
                  buffer-face-mode-face 'variable-pitch)
      (expect (ia/variable-pitch-p) :to-be nil))))

;;; ia-face-test.el ends here
