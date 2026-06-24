;;; ia-cape-capf-sort-utility.el --- Sort functions for corfu & cape  -*- lexical-binding: t; -*-

;;; Commentary:
;; 

;; Note: Grouping backends with `cape-capf-super' in
;; `ia/capf-with-presort' requires the correct one to be first
;; specified that fits the buffer type, so it obeys the correct
;; boundary rules, in programming modes, the symbol capf back
;; end should be first, otherwise the compiletion will
;; expectedly auto fill, if a word back end is first.
(defun ia/capf-sort-length-alpha (candidates)
  "Sort CANDIDATES by length, then alphabetically."
  (sort candidates
        (lambda (a b)
          (let ((la (length a))
                (lb (length b)))
            (if (= la lb)
                (string< a b)
              (< la lb))))))

(defun ia/capf-with-presort (capf sort-fn)
  "Wrap CAPF so its underlying completion table returns candidates pre-sorted by SORT-FN."
  (lambda ()
    (when-let ((res (funcall capf)))
      (let ((beg (nth 0 res))
            (end (nth 1 res))
            (table (nth 2 res))
            (plist (nthcdr 3 res)))
        (append
         (list beg end
               (lambda (string pred action)
                 (let ((result (complete-with-action action table string pred)))
                   (if (and (eq action t) (listp result))
                       (funcall sort-fn result)
                     result))))
         plist)))))

(defun ia/capf-backend-prior-dedup-sort (sort-fn)
  "Create a Corfu sorting function that deduplicates by backend priority.
The resulting function eliminates clones (tagged by `cape-capf-super`) 
in favor of primary candidates, then applies SORT-FN to the unique list."
  (lambda (candidates)
    (let ((seen (make-hash-table :test 'equal))
          (unique-candidates nil)
          clones)
      ;; 1. Single linear pass: Siphon clones into a deferred list
      (dolist (cand candidates)
        (if (get-text-property 0 'cape-capf-super cand)
            (push cand clones)
          (unless (gethash cand seen)
            (puthash cand t seen)
            (push cand unique-candidates))))
      ;; 2. Process the deferred clones
      (dolist (cand clones)
        (unless (gethash cand seen)
          (puthash cand t seen)
          (push cand unique-candidates)))
      ;; 3. Execute the dynamically passed sorting engine
      (funcall sort-fn (nreverse unique-candidates)))))


(provide 'ia-cape-capf-sort-utility)

;;; ia-cape-capf-sort-utility.el ends here
