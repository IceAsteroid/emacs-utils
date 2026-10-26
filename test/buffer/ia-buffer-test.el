;;; ia-buffer-test.el --- Tests for the buffer utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the token-aware kill commands.

;;; Code:

(require 'buttercup)
(require 'ia-buffer-utility)

(defun ia/test-kill (command text position)
  "Call COMMAND in a temp buffer with TEXT, at POSITION.
POSITION is an integer or `end' for the end of the buffer.  Return the
buffer text after the command."
  (with-temp-buffer
    (insert text)
    (goto-char (if (eq position 'end) (point-max) position))
    (let ((kill-ring nil))
      (funcall command)
      (buffer-string))))

(describe "ia/backward-kill-word"
  (it "kills the word before point and leaves the space"
    (expect (ia/test-kill #'ia/backward-kill-word "foo bar" 'end)
            :to-equal "foo "))
  (it "kills a word and the one space before it"
    (expect (ia/test-kill #'ia/backward-kill-word "foo bar" 5)
            :to-equal "bar"))
  (it "kills a whitespace gap alone when it has two or more characters"
    (expect (ia/test-kill #'ia/backward-kill-word "foo  bar" 6)
            :to-equal "foobar"))
  (it "kills identical adjacent delimiters as one token"
    (expect (ia/test-kill #'ia/backward-kill-word "foo__bar" 'end)
            :to-equal "foo__")))

(describe "ia/kill-word"
  (it "kills the word after point"
    (expect (ia/test-kill #'ia/kill-word "foo bar" 1)
            :to-equal " bar"))
  (it "kills a word and the one space before it"
    (expect (ia/test-kill #'ia/kill-word "foo bar" 4)
            :to-equal "foo"))
  (it "kills a whitespace gap alone when it has two or more characters"
    (expect (ia/test-kill #'ia/kill-word "foo  bar" 4)
            :to-equal "foobar"))
  (it "kills identical adjacent delimiters as one token"
    (expect (ia/test-kill #'ia/kill-word "foo__bar" 4)
            :to-equal "foobar")))

;;; ia-buffer-test.el ends here
