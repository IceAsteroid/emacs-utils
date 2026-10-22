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

There is no build, lint or test target in the repository.  Write the
checks under `/tmp`; never leave an `.elc` beside the source.

- Byte-compile a copy: copy the files to `/tmp` and run
  `emacs -Q --batch -L /tmp -L <deps> -f batch-byte-compile FILE`; the
  `.elc` appearing is the signal, and a clean compile prints nothing.
- Run the batch harnesses with `emacs -Q --batch -l FILE > OUT 2>&1`;
  redirect explicitly, since batch output piped into `head` can come
  back empty.
- Run checkdoc on the changed files.
- Interactive prompts need a pty.  Reproduce with `emacs -Q` and a
  minimal file under `/tmp`.  Never load the user's init or desktop: it
  restores private buffers, and keystrokes can reach them.
- Cite the file and line for a mechanism you read.  Mark a statement
  you have not checked as unverified.  Report what was verified and
  what was not.

The checks are scripts outside the repository, usually under `/tmp`.
The current ones for the display work are `ia-display-ask-test.el`,
`ia-order-test.el` and `ia-tab-frame-test.el`.

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
