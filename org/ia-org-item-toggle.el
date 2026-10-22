;;; ia-org-item-toggle.el --- Toggle org items like headings  -*- lexical-binding: t; -*-

;;; Commentary:
;; Consider taking this code to its own repo or in my emacs-util repo.
;; Deploy functions to hide/show contexts of items in org-mode
;; The implementation needs refactor when I get time

(require 'org)

;;; Code:

(defvar my/org-fold-hide-item-cycle-view-list '(folded children subtree)
  "List of view states for items to cycle.")

(defvar my/org-fold-hide-item-cycle-view 'folded
  "Default view state for first run as in `my/org-fold-hide-item-cycle-view-list'")

(defun ia/org-item-nesting-level (item)
  "Return the nesting level of an Org ITEM.
A first-level item returns 1, a nested item returns 2, and so on.  ITEM should
be an element of type 'item produced by `org-element-parse-buffer`."
  (let ((level 1)
        ;; The direct parent of an 'item is a plain-list.
        (parent (org-element-property :parent item)))
    (while (and parent (eq (org-element-type parent) 'plain-list))
      ;; The plain-list’s parent is the item that contained it, if any.
      (let ((upper (org-element-property :parent parent)))
        (if (and upper (eq (org-element-type upper) 'item))
            (progn
              (setq level (1+ level))
              ;; And now set parent to the plain-list of that ancestor item.
              (setq parent (org-element-property :parent upper)))
          (setq parent nil))))
    level))

(defun ia/org-item-map (function &optional start end level only-visible)
  "Act like `org-map-entries' for items which moves point to each item line and applies the function to it in org-mode.
`start' & `end' specify the beginning & end positions for mapping.  `level'
limits to the level item to map to.  `only-visible' if is t, map only to visbile
item lines(unfolded), otherwise to all item lines."
  (let* ((start (or start (point-min)))
         (end (or end (point-max))))
    (save-restriction
      (narrow-to-region start end)
      (org-element-map (org-element-parse-buffer) 'item
        (lambda (item)
          (save-excursion
            (goto-char (org-element-property :begin item))
            ;; Move forwawrd one char as the first char's property in a item
            ;; line is a plain list instead of the item's.
            (forward-char 1)
            (when (or (not level)
                      (<= (ia/org-item-nesting-level item)
                          level))
              (if only-visible
                  (unless (get-char-property (point) 'invisible)
                    (funcall function item))
                (funcall function item)))))))))

(defun ia/org-fold-hide-item-all (&optional view)
  (interactive)
  (let ((view (or view 'folded)))
    (ia/org-item-map
     (lambda (&rest _)
       (org-list-set-item-visibility (line-beginning-position) (org-list-struct) view))
     nil nil 1 'only-visible)
    (setq my/org-fold-hide-item-cycle-view view)
    (message "Item view: %s" view)))

(defun ia/org-fold-hide-item-toggle ()
  (interactive)
  (let ((next-view (or (cadr (member my/org-fold-hide-item-cycle-view
                                     my/org-fold-hide-item-cycle-view-list))
                       ;; If in a last elem as its next elem is nil, return
                       ;; the first elem of the list.
                       (car my/org-fold-hide-item-cycle-view-list))))
    (if (eq this-command last-command)
        (ia/org-fold-hide-item-all next-view)
      (setq my/org-fold-hide-item-cycle-view 'folded)
      (ia/org-fold-hide-item-all my/org-fold-hide-item-cycle-view))))


(provide 'ia-org-item-toggle)

;;; ia-org-item-toggle.el ends here
