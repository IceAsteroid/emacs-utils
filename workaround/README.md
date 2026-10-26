# Workarounds

Each file in this directory is one workaround for a single Emacs bug
(or a single regression caused by a bug fix).  The files require
`ia-core-utility` for `ia/feat-chunk`; load that library before a
workaround, or replace the macro with `when` when you copy a file into
another configuration.  This README documents the file naming and
identifier conventions so that new workarounds remain consistent with
existing ones.

## Naming scheme

One bug per file.  Group multiple bugs into one file only when they
share a single root cause (e.g. one upstream commit broke several
things and one workaround fixes them all).

File names follow:

```
ia-fix-<category>-<symptom>-<bugNumber>.el
```

- `<category>` — the area/package the bug lives in (e.g. `pgtk`,
  `man`, `gt`, `theme`, `window`).
- `<symptom>` — a short, stable description of the bug or symptom
  (e.g. `treesit-hang`, `osc8-hyperlink`, `childframe-lag`).
- `<bugNumber>` — the upstream bug anchor, **suffix only when one
  exists**:

  | anchor | meaning | example |
  |---|---|---|
  | debbugs number | GNU Emacs bug tracker | `81240`, `58556`, `68880` |
  | GitHub issue number | a third-party package issue | `lorniu/gt.el#82` → `82` |
  | *(omitted)* | no bug filed; keep topic-only | `ia-fix-<category>-<symptom>.el` |

  Prefer a bug number over a commit hash: bug numbers are stable,
  greppable from reports, and survive fix-commit churn.  Use a commit
  hash only as a fallback when no bug is filed, and even then keep the
  topic suffix.

For bugs without a number, the topic alone is the whole name.  Add a
symptom qualifier only when a category gets a second bug
(e.g. `ia-fix-pgtk-childframe-lag-58556.el` when another pgtk
workaround appears).

The bug number goes **before** any function-specific detail, not at
the very end of symbols: the number is the stable anchor that groups
a workaround's symbols together, while the trailing detail describes
what a function does and is the part most likely to be renamed.

## Identifier conventions

The `provide` feature must match the file base name, and internal
symbols mirror the file name with `ia-fix-` → `ia-fix/`:

| file | chunk / namespace | function / variable |
|---|---|---|
| `ia-fix-gt-treesit-hang-82.el` | `ia-fix/gt-treesit-hang-82` | `ia-fix/gt-treesit-hang-82-ensure-progress` |
| `ia-fix-man-osc8-hyperlink-81240.el` | `ia-fix/man-osc8-hyperlink-81240` | `ia-fix/man-osc8-hyperlink-81240` |
| `ia-fix-org-block-regexp-overflow.el` | `ia-fix/org-block-regexp-overflow` | `ia-fix/org-block-regexp-overflow--fix` |
| `ia-fix-pgtk-childframe-lag-58556.el` | `ia-fix/pgtk-childframe-lag-58556` | — |
| `ia-fix-theme-custom-theme-set-faces-68880.el` | `ia-fix/theme-custom-theme-set-faces-68880` | `ia-fix/theme-custom-theme-set-faces-68880-mode`, `ia-fix/theme-custom-theme-set-faces-68880--native-...` |
| `ia-fix-window-state-put-73627.el` | `ia-fix/window-state-put-73627` | `ia-fix/window-state-put-73627--advice` |

- Private helpers use `--` (e.g. `ia-fix/theme-custom-theme-set-faces-68880--set`).
- Hook functions use the `ia-hook/` prefix (e.g. `ia-hook/theme-custom-theme-set-faces-68880-apply-generic-theme-overrides`).

## Commentary requirements

Each file's `;;; Commentary:` must record the upstream anchor and the
fix status, so a reader can verify whether the workaround is still
needed:

- The bug number and, when it differs from the bug, the bug that the
  workaround actually addresses.  A workaround for a **regression
  introduced by a bug fix** must say so explicitly (e.g. the
  window-state-put workaround exists because of the *fix* for
  Bug#73627, not the bug itself).
- The upstream fix commit and the Emacs version it landed in (if
  fixed), plus whether it was backported — this drives the version
  gate (e.g. `< 32`) and tells you when to drop the file.
- For third-party issues, the full URL (e.g.
  `https://github.com/lorniu/gt.el/issues/82`); for debbugs, the
  tracker URL (e.g. `https://debbugs.gnu.org/81240`).

## Version gating

Use `(ia/feat-chunk ...)` with an explicit version predicate so the
workaround is not evaluated once the upstream fix is present.  The
predicate is evaluated when the file loads:

```elisp
(ia/feat-chunk ia-fix/gt-treesit-hang-82 (< emacs-major-version 32) ...)
```

Re-test after each major Emacs upgrade and drop files whose fix has
landed.

## Loading

Workarounds are `require`d individually from `init.el`; keep the
`require` name in sync with the file's `provide`.
