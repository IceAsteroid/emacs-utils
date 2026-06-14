;;; fix-pgtk.el --- Workarounds for pgtk related bugs  -*- lexical-binding: t; -*-

;;; Code:
(require 'init-common)

(ia/feat-chunk ia-fix/input-or-childframe-lag t
  ;; corfu, lsp-bridge child-frame popup abortion by space or other no
  ;; match insertion have lag, if `pgtk-wait-for-event-timeout' is the
  ;; default 0.1 value.
  (when (string-search "PGTK" system-configuration-features)
    (setq pgtk-wait-for-event-timeout 0.005)))

(provide 'fix-pgtk)

;;; fix-pgtk.el ends here
