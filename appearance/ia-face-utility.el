;;; ia-face-utility.el --- Small snippets for face operations

;;; Commentary:
;; 

;;; Code:

(defun ia/variable-pitch-p ()
  "Return non-nil if the current buffer is actively using a variable-pitch face."
  (and (bound-and-true-p buffer-face-mode)
       (eq buffer-face-mode-face 'variable-pitch)))

(provide 'ia-face-utility)

;;; ia-face-utility.el ends here
