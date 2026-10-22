# Instructions for coding agents

This repository follows `TERM_AND_CONVENTION.md`.  Read it before
writing anything, including the reply that explains a change; it binds
every word of this work.

Run the three checks on each noun and verb: is it a Core term, is it in
Terms not used, and does Emacs have the word?  When Emacs has the word,
use it; when a function or option implements the concept, name it.  A
wording that is not in the file needs the maintainer's agreement before
it is used.

## The repository

A collection of Emacs Lisp utilities, one file per feature.  The files
the display work touches:

- `layout/ia-display-buffer-action.el` — the display action mode, the
  tab and frame prompts, the split decision.
- `layout/ia-window-utility.el` — the window test, the split options,
  the window prompt.
- `layout/ia-window-prefix-pivot.el` — the window prefix commands and
  the pivot.
- `layout/ia-tab-bar-modified.el` — the tab candidates, history and
  the function that reads a tab name.
- `layout/ia-tab-bar-modified-consult.el` — the consult integration.

The user's uncommitted files are not yours.  Stage explicit paths,
never a directory; leave a file you were not asked to change alone.

## Verifying work

Run `make check`: it byte-compiles the five layout files in a temporary
directory and runs the tests under `test/`, and the `.elc` never lands
beside the source.  `make checkdoc` reports the docstring findings; the
two `C-g` literals in the action and the window utility are the
maintainer's choice, so checkdoc prints them on every run.

- The tests are batch Emacs Lisp files under `test/`, mirroring the
  source directories (`test/layout/` for the layout files), each exiting
  non-zero when a check fails.
- The Makefile finds ace-window, avy and consult under `ELPA`, which
  defaults to `$(HOME)/.emacs.d/elpa`; override `ELPA` or `EMACS` when
  they live elsewhere.
- Docstrings wrap at 80 columns.  A `defvar` or `defcustom` docstring
  longer than 80 columns makes the byte-compiler warn; checkdoc reports
  the rest.
- The tested Emacs is 31.1; the minimum version is not established.
  The tests run on Linux; no other platform is tested.
- Interactive prompts need a pty.  Reproduce with `emacs -Q` and a
  minimal file under `/tmp`.  Never load the user's init or desktop: it
  restores private buffers, and keystrokes can reach them.
- Cite the file and line for a mechanism you read.  Mark a statement you
  have not checked as unverified.  Report what was verified and what was
  not.

## Commits

This repository uses per-change commits; `~/.emacs.d` uses monthly
commits.  Follow `TERM_AND_CONVENTION.md` for the message: present
tense, the body labels, wrapped at 72 columns, one atomic change with
its documentation, a documentation-only change as its own commit, and
explicit paths.

Do not rewrite an existing commit.  A message that violates a later
rule keeps its form; a message that is wrong under a rule already in
force is reported to the maintainer, and a rewrite waits for the
maintainer's word.

The `Terms not used` list is the source for a word checker: a checker
reads the forms from the codification and leaves the codification file
itself out.
