;;; ia-cape-test.el --- Tests for the completion sorting utilities  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for the candidate sorters and the capf wrapper.

;;; Code:

(require 'buttercup)
(require 'ia-cape-capf-sort-utility)

(describe "ia/capf-sort-length-alpha"
  (it "sorts by length, then alphabetically"
    (expect (ia/capf-sort-length-alpha '("bbb" "a" "cc" "ab"))
            :to-equal '("a" "ab" "cc" "bbb"))))

(describe "ia/capf-with-presort"
  (it "sorts the candidates of the wrapped capf"
    (let* ((capf (lambda () (list 1 2 '("bbb" "a" "cc") :props t)))
           (wrapped (ia/capf-with-presort capf #'ia/capf-sort-length-alpha))
           (result (funcall wrapped)))
      (expect (funcall (nth 2 result) "" nil t)
              :to-equal '("a" "cc" "bbb"))
      (expect (nthcdr 3 result) :to-equal '(:props t)))))

(describe "ia/capf-backend-prior-dedup-sort"
  (it "keeps one copy of a clone and sorts the result"
    (let* ((primary "a")
           (clone (propertize "a" 'cape-capf-super t))
           (other "bb")
           (sorted (funcall (ia/capf-backend-prior-dedup-sort
                             #'ia/capf-sort-length-alpha)
                            (list clone other primary))))
      (expect sorted :to-equal '("a" "bb")))))

;;; ia-cape-test.el ends here
