# Changelog

## Unreleased

- Doc: `workaround/README.md`, the naming and identifier conventions
  for the workaround files.
- Add: `workaround/ia-fix-window-state-put-73627.el`, the workaround for
  the `window-state-put' recursion with a side window.
- Add: `workaround/ia-fix-org-block-regexp-overflow.el`, the workaround
  for the Org 9.7 block regexp stack overflow.
- Add: `workaround/ia-fix-gt-treesit-hang-82.el`, the workaround for
  the gt.el tree-sitter hang in `gt-forward-thing'.
- Add: `layout/ia-popper-modified.el`, which displays a popper window
  at the bottom of the selected window's column, anchors a popper
  displayed from a side window to a main-area window chosen by
  `ia/popper-side-window-target', and gives `popper-toggle' a
  three-state cycle.
- Add: `org/ia-org-utility.el`, which defines
  `ia/org-redisplay-inline-images-at-block`, refreshing the inline
  images of the source block at point, or of the block in
  `org-babel-current-src-block-location', and
  `ia/org-remove-blank-line-before-results-mode`, removing the blank
  line that `org-babel--insert-results-keyword' inserts before a
  results block.
- Add: the utility collection under `appearance/`, `buffer/`,
  `completion/`, `core/`, `doc-lookup/`, `info-inbox/`, `layout/`,
  `org/` and `workaround/`, and `emacs-utils.el`, the entry point that
  adds them to `load-path`.
- Add: `layout/ia-display-buffer-action.el`, which defines
  `ia/display-buffer-action-mode` and its `display-buffer-alist` entry:
  a buffer is displayed in a window that already shows it, else in the
  selected window, else in a window chosen with `ace-window`, with the
  split rule `ia/window-split-p` and the shared window prompt.
- Add: `layout/ia-display-buffer-action.el` and
  `layout/ia-tab-bar-modified.el`, the tab and frame prompts, with the
  tab history and candidates, the chosen window prompt and the frame's
  tab prompt.
- Add: `layout/ia-window-prefix-pivot.el`, which defines
  `ia/other-tab-prefix`: it asks for the tab of the next command's
  buffer, or a new one, and displays the buffer there.
- Add: `layout/ia-window-prefix-pivot.el`, which adds
  `ace-other-window-select`, deciding the selected window after the
  prefix displays the buffer.
- Fix: `layout/ia-window-utility.el` and
  `layout/ia-display-buffer-action.el`: with one window,
  `switch-to-buffer-other-window` reused the sole window instead of
  splitting it; the choice now declines and the caller's action
  functions split.
- Fix: `layout/ia-display-buffer-action.el` and
  `layout/ia-tab-bar-modified.el`: `RET` at the tab prompt selected the
  current tab and made no new tab; an empty initial name now makes a new
  tab.
- Fix: `layout/ia-window-prefix-pivot.el`: a new tab made while the tab
  prompt was open showed the prompt again and again; a nested display
  now declines while the tab step runs.
- Fix: `layout/ia-display-buffer-action.el`: the one-window prompt
  named split keys that the user had rebound; the help now reads the
  keys and descriptions from `aw-dispatch-alist`.
- Fix: `layout/ia-display-buffer-action.el`: a key that is not a split
  key at the one-window prompt signaled `Invalid function`; any other
  key now uses the window.
- Refactor: `layout/ia-window-utility.el`, the split rule and the
  window prompt shared by `ia-display-buffer-action` and
  `ia-window-prefix-pivot`.
- Refactor: `layout/ia-tab-bar-modified.el` and
  `layout/ia-tab-bar-modified-consult.el`, the tab package's data and
  reader separated from its consult integration.
- Test: `test/layout/`, `Makefile`, `Eldev` and
  `.github/workflows/test.yml`: buttercup suites run by `eldev test`
  through `make check`, and the workflow that runs the checks on every
  push and pull request.
- Doc: `TERM_AND_CONVENTION.md` and `AGENTS.md`: the codification and
  the coding-agent instructions; the three initial snapshots split into
  thirteen feature commits and the fix messages rewritten to state
  their symptoms and fixes, with no commit tree changed.
- Doc: `layout/ia-display-buffer-action.el` and
  `layout/ia-window-prefix-pivot.el`: the tab and frame prompts say
  prompt, Emacs's word for the `completing-read` argument.
- Doc: `emacs-utils.el`: the package header lists only the direct
  dependencies, ace-window and consult; avy comes through ace-window.
