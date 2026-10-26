;;; ia-core-test.el --- Tests for the core utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the substring helpers, the feature chunk macro and the
;; directory loader in `ia-core-utility'.

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'ia-core-utility)

(describe "ia/ensure-substring"
  (it "adds a missing substring after the string"
    (expect (ia/ensure-substring "foo" "bar" " ") :to-equal "foo bar"))
  (it "leaves a string that already contains the substring"
    (expect (ia/ensure-substring "foo bar" "bar" " ") :to-equal "foo bar"))
  (it "adds a missing substring before the string when PREPEND is non-nil"
    (expect (ia/ensure-substring "foo" "bar" " " t) :to-equal "bar foo"))
  (it "treats SUBSTRING as a literal by default"
    (expect (ia/ensure-substring "foo" "o+" " ") :to-equal "foo o+"))
  (it "treats SUBSTRING as a regexp when REGEXP-P is non-nil"
    (expect (ia/ensure-substring "foo" "o+" " " nil t) :to-equal "foo")))

(describe "ia/ensure-substring-item"
  (it "adds a missing item after the list"
    (expect (ia/ensure-substring-item "foo bar" "baz" " ")
            :to-equal "foo bar baz"))
  (it "does not match a partial item"
    (expect (ia/ensure-substring-item "foo bar" "fo" " ")
            :to-equal "foo bar fo"))
  (it "leaves an item that is already present"
    (expect (ia/ensure-substring-item "foo bar" "bar" " ")
            :to-equal "foo bar"))
  (it "adds an item before the list when PREPEND is non-nil"
    (expect (ia/ensure-substring-item "foo bar" "baz" " " t)
            :to-equal "baz foo bar")))

(defvar ia/test-feat-flag nil)
(defvar ia/test-feat-value nil)

(describe "ia/feat-chunk"
  (before-each
    (setq ia/test-feat-flag nil
          ia/test-feat-value nil))
  (it "does not evaluate the body when the predicate is nil"
    (eval '(ia/feat-chunk test ia/test-feat-flag
             (setq ia/test-feat-value t)))
    (expect ia/test-feat-value :to-be nil))
  (it "evaluates the body when the predicate is non-nil"
    (setq ia/test-feat-flag t)
    (eval '(ia/feat-chunk test ia/test-feat-flag
             (setq ia/test-feat-value t)))
    (expect ia/test-feat-value :to-be t)))

(describe "ia/load-dir-recursive"
  (it "passes FOLLOW-SYMLINKS to `byte-recompile-directory'"
    (let* ((root (make-temp-file "ia-core-test-" t))
           (package (expand-file-name "pkg" root))
           (received nil)
           (load-path load-path))
      (unwind-protect
          (progn
            (make-directory package)
            (let ((ia/local-packages-dir root))
              (cl-letf (((symbol-function 'byte-recompile-directory)
                         (lambda (&rest args) (setq received args))))
                (ia/load-dir-recursive "pkg" nil nil nil 'follow-symlinks)))
            (expect (nth 3 received) :to-be 'follow-symlinks))
        (delete-directory root t)))))

;;; ia-core-test.el ends here
