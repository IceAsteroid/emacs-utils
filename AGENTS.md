# Instructions for coding agents

This repository follows `TERM_AND_CONVENTION.md`.  Read it before
writing a change or the reply that describes it.

Check prose against the codification: is the word a Core term, is it in
Terms not used, and does Emacs have the word?  Code, identifiers and
shell commands are not prose.

## The repository

A personal collection of Emacs Lisp libraries and command files, one
file per feature.  The display action, pivot, window test, split
options, window prompt and tab bar reader are in their own repository;
the `ia/other-window-mru` command and the consult integration remain in
`layout/`.  The consult integration consumes the display package's
optional `display-buffer-pivot-tab-bar-consult` library, sets
`display-buffer-pivot-tab-bar-read-function` to its reader when the mode
is enabled, and calls its child-frame cleanup for the built-in overrides.
`README.md` lists the directories; the `Makefile` comments state what
`FILES` and `CHECK_FILES` hold.

The user's uncommitted files are not yours.  Stage explicit paths,
never a directory; leave a file you were not asked to change alone.

## Verifying work

Run `make check`: it checks the library graph, byte-compiles the files
`CHECK_FILES` names, and runs the tests under `test/` with
`eldev test`.  `make checkdoc` reports the docstring findings.  The
consult integration needs the display package; the Makefile uses
`../display-buffer-pivot`, or the directory named by
`DISPLAY_PACKAGE`.  GitHub Actions runs both commands on every push and
pull request.

- The tests are buttercup files under `test/`; `README.md` lists the
  directories.  The layout files have no tests; the display tests are in
  the display package.  New tests use `describe`/`it`/`expect`.
- The Makefile finds ace-window, avy and consult under `ELPA` for the
  compile and checkdoc, and the display package at
  `../display-buffer-pivot`; `eldev test` installs buttercup into
  `.eldev`, which is ignored.
- Docstrings wrap at 80 columns.  A `defvar` or `defcustom` docstring
  longer than 80 columns makes the byte-compiler warn; checkdoc reports
  the rest.
- The tested Emacs is 31.1; the minimum version is not established.
  The tests run on Linux; no other platform is tested.
- Interactive prompts need a pty.  Reproduce with `emacs -Q` and a
  minimal file under `/tmp`.  Never load the user's init or desktop: it
  restores private buffers, and keystrokes can reach them.
- Cite the file and line for a mechanism you read.  Mark a statement
  you have not checked as unverified.  Report what was verified and
  what was not.

## Commits

This repository uses per-change commits; `~/.emacs.d` uses monthly
commits.  Follow the codification for the message and the atomic-commit
rule; stage explicit paths.  Do not rewrite an existing commit.

The `Terms not used` list is the source for the word checker; the
checker reads prose, not code, identifiers or shell commands.
