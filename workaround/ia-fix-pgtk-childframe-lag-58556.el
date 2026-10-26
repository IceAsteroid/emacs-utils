;;; ia-fix-pgtk-childframe-lag-58556.el --- Fix PGTK child-frame popup lag  -*- lexical-binding: t; -*-

;;; Commentary:
;; Workaround for Emacs bug #58556 (merged with #52677 and #81014):
;; on PGTK builds, `make-frame-visible'/`make-frame-invisible' wait
;; out the whole `pgtk-wait-for-event-timeout' (default 100ms), which
;; makes corfu/lsp-bridge child-frame popups lag when they abort by
;; space or another no-match insertion.
;;
;; Bug: https://debbugs.gnu.org/58556
;;
;; Affected versions: PGTK builds 29 through 31.  PGTK itself does
;; not exist in Emacs 28 (the port landed in 29), so the bug cannot
;; occur before 29.  Bug#81014 was reported against 30.2 (2026-05),
;; and the `emacs-31' branch still carries the unpatched
;; `pgtk_wait_for_map_event' with `multiple_times=t' and the default
;; 0.1 timeout.
;;
;; Fix: commit 7d07be05a275 "Improve the process of waiting until a
;; timeout occurs (bug#81014)" (2026-08-24, master / Emacs 32 only).
;; Not backported to 31, so the workaround runs only on PGTK builds
;; of 29..31.
;;
;; This issue is hard to write tests, since the lag depends on the
;; user computer's performance, it requires to manually turn off and
;; on when a new major version of Emacs comes out and see if it
;; fixes.

(require 'ia-core-utility)

;;; Code:

(ia/feat-chunk ia-fix/pgtk-childframe-lag-58556 (and (>= emacs-major-version 29)
                                                     (< emacs-major-version 32))
  ;; corfu, lsp-bridge child-frame popup abortion by space or other no
  ;; match insertion have lag, if `pgtk-wait-for-event-timeout' is the
  ;; default 0.1 value.
  (when (string-search "PGTK" system-configuration-features)
    (setq pgtk-wait-for-event-timeout 0.005)))

(provide 'ia-fix-pgtk-childframe-lag-58556)

;;; ia-fix-pgtk-childframe-lag-58556.el ends here
