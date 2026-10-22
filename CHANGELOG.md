# Changelog

## Unreleased

- Add: the utility collection under `appearance/`, `buffer/`,
  `completion/`, `core/`, `doc-lookup/`, `info-inbox/`, `layout/`,
  `org/` and `workaround/`, and the `emacs-utils.el` entry point that
  adds them to `load-path`.
- Add: `ia/display-buffer-action-mode`, a `display-buffer-alist` entry
  that displays a buffer in a window that already shows it, else in the
  selected window, else in a window chosen with `ace-window`, with the
  split rule `ia/window-split-p` and the shared window prompt.
- Add: the tab and frame prompts of the display rule, with the tab
  history and candidates, the chosen window prompt and the frame's tab
  prompt.
- Add: `ia/other-tab-prefix`, which asks for the tab of the next
  command's buffer, or a new one, and displays the buffer there.
- Add: `ace-other-window-select`, which decides the selected window
  after the prefix displays the buffer.
- Fix: with one window, `switch-to-buffer-other-window` reused the sole
  window instead of splitting it; the choice now declines and the
  caller's action functions split.
- Fix: `RET` at the tab prompt selected the current tab and made no new
  tab; an empty initial name now makes a new tab.
- Fix: a new tab made while the tab prompt was open showed the prompt
  again and again; a nested display now declines while the tab step
  runs.
- Fix: the one-window prompt named split keys that the user had
  rebound; the help now reads the keys and descriptions from
  `aw-dispatch-alist`.
- Fix: a key that is not a split key at the one-window prompt signaled
  `Invalid function`; any other key now uses the window.
- Refactor: the split rule and the window prompt are shared by
  `ia-display-buffer-action` and `ia-window-prefix-pivot` in
  `ia-window-utility`.
- Refactor: the tab package's data and reader are separated from its
  consult integration.
- Test: buttercup suites under `test/layout/`, run by `eldev test`
  through `make check`, and a GitHub Actions workflow that runs the
  checks on every push and pull request.
- Doc: added `TERM_AND_CONVENTION.md` and `AGENTS.md`; split the three
  initial snapshots into thirteen feature commits and rewrote the
  display-work commit messages to state their symptoms and fixes.  No
  commit tree changed.
- Doc: the tab and frame prompts say prompt, Emacs's word for the
  `completing-read` argument; the package header lists only the direct
  dependencies.
