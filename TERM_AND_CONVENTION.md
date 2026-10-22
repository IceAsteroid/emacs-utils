# emacs-utils — Terms and conventions

This file is the codification for this repository.  It binds every
change, including code, Commentary, docstrings, commit messages and the
replies that describe them.  A term is added to "Core terms" with the
maintainer's agreement before it is used; a term that is dropped moves
to "Terms not used" with its replacement.  When this file and the code
disagree, report both sites and leave the fix until it is asked for.

## Core terms

Use Emacs's own name whenever Emacs has one.  The entries below are the
concepts this repository names; most of them are Emacs's, and each
entry says where Emacs defines it.

- **display action** — Emacs's `(FUNCTIONS . ALIST)` argument of
  `display-buffer`; see the (elisp) Buffer Display Action Functions and
  Buffer Display Action Alists nodes.
- **action function** — a function `display-buffer` calls with the
  buffer and the action alist; it displays the buffer and returns the
  window, or returns nil.
- **action alist** — the alist an action function receives, as Emacs
  defines it.
- **entry** — one element of `display-buffer-alist`: a condition and
  the display action it selects.  `ia/display-buffer-action-mode` conses
  one entry at the front; `ia/display-buffer-action-control-p` is its
  condition.
- **condition** — the key of an entry.  `display-buffer-assq-regexp`
  passes it to `buffer-match-p` with the buffer name and the ACTION
  argument of the call.
- **window prefix** — Emacs's `other-window-prefix` and
  `display-buffer-override-next-command`.  This repository replaces
  some of those commands with `ace-other-window-prefix` and
  `ia/other-tab-prefix`.
- **pivot** — the advice `window-prefix-pivot-ad-display-buffer` in
  `ia-window-prefix-pivot.el`, installed by
  `ia/window-prefix-pivot-mode`.  While a window prefix is armed and
  the selected window cannot display a buffer, it runs the display from
  the most recently used editing window, so the prefix's placement does
  not use the utility window that was selected.  The name is this
  repository's; Emacs has no name for the advice's job.
- **popup window**, **column popup**, **popup buffer**, **origin** —
  column-popup's terms.  Use them as that package defines them in its
  own `TERM_AND_CONVENTION.md`; they are not terms of this repository.

A concept that is neither here nor named by Emacs: name the function or
option that implements it, rather than coining a noun.

## Terms not used

These forms are avoided in code, Commentary, docstrings, commit
messages and the replies that describe them.  Each entry gives the
phrasing to use instead.  The entries that name column-popup's own
concepts remain in its file; they are not repeated here because they do
not name anything in this repository.

- adopt / adopted — describe the action: use, select or apply the
  thing, whichever is meant.
- session — say the call or the command, or "while the minibuffer is
  active", whichever is meant.
- display time — "when the `display-buffer` call runs" or "at the time
  of the `display-buffer` call".
- echo — "echo area" is Emacs's term for the area where messages
  appear; use it rather than "the echo".  Identifiers keep the `echo`
  prefix, as Emacs does (`echo-keystrokes`).
- task context — delete the phrase, or say "the minibuffer".
- claim / claimed — say which thing does what: a window displays a
  buffer, a condition selects an entry, an action function displays the
  buffer.
- stays / stayed — "remains / remained".
- summon / summoned — "display / displayed" for a buffer, "make / made"
  for a window, frame or tab.
- spawn / spawned / spawning — "make / made" for a window, frame or
  tab; "display / displayed" for a buffer.
- open a buffer / create a buffer — say "display a buffer in a window".
  A function that creates a buffer names `get-buffer-create`; the
  display rule never creates one.
- question, for the prompt of `completing-read` — say "prompt", or name
  the function that reads (`ia/tab-bar-modified-read-tab-name`).  Emacs
  calls the first argument of `completing-read` PROMPT; its docstring
  says "PROMPT is a string to prompt with".

## Conventions

Commit messages, and the Commentary and docstrings where they state
behavior, follow these rules.

- Present tense for verbs.  A title describes the current behavior; a
  body paragraph uses the labels below.
- Body paragraphs are labeled: `Symptom:` (present tense: what the user
  does and what the user sees), `Root cause:` (present tense: why the
  code misbehaved), `Fix:` (imperative: the change), `Add:` (present
  tense: what the change adds), `Doc:` (present tense: what the
  documentation states).  A fix labels Symptom, Root cause and Fix; a
  feature labels Add; a commit that carries the documentation of its
  change labels Doc.  A commit labels the paragraphs its change needs
  and leaves the others out.  This repository has no `BUGS.md`; a fix
  has no bug entry to write and its message is the record.
- A rule binds what is written after it is stated.  An earlier message
  or file keeps its form.
- Name the command, not a keybinding.  A key in a docstring or a
  message is a suggestion the user may have changed; refer to
  `ia/other-tab-prefix`, not to `C-x t t`.
- One atomic commit per logical change: the code and the documentation
  of that change in the same commit, so a checkout of any commit shows
  the code and the documentation that describe it, and the commit can
  be reverted on its own.  A change that touches only documentation is
  its own commit; unrelated changes are separate commits even when they
  touch one file.
- Subject type prefixes: `feat:` for a new behavior or option, `fix:`
  for a correction, `refactor:` for a change that keeps behavior,
  `docs:` for documentation only, and `test:` for a change that only
  adds or changes tests.  The subject is a present-tense phrase after
  the prefix.
- Wrap commit-message lines at about 72 columns.  Write the message to a
  file and pass it with `git commit -F`; check the result with
  `git log -1 --format=%B | awk 'length > 72'`.
- Wrap docstrings at 80 columns.  A `defvar` or `defcustom` docstring
  longer than 80 columns makes the byte-compiler warn; checkdoc reports
  the rest.
- Do not rewrite an existing commit.  A message that violates a rule
  written after it keeps its form; a message that is wrong under a rule
  already in force is reported to the maintainer, and a rewrite waits
  for the maintainer's word.
- A term must be added to "Core terms" with the maintainer's agreement
  before it is used; a term that is dropped moves to "Terms not used"
  with its replacement.
- Never introduce a preferred wording or term without asking first.
  Propose it with the reason; the established word wins unless the
  maintainer agrees.
- Coin terms sparingly.  A term earns its place only when it is
  shorter, unambiguous and reads naturally; otherwise keep the plain
  phrasing.  A term's explanation lives in this file.
- Window and buffer language: a window displays a buffer; a buffer is
  not "opened" by a display function.  Say "display the buffer in the
  window"; a function that creates a buffer names `get-buffer-create`.
- Quote a symbol or a code fragment with a grave accent on both sides
  in Markdown and commit messages, e.g. `ia/other-tab-prefix`; in Emacs
  Lisp source use a grave accent before and an apostrophe after, e.g.
  `ia/other-tab-prefix'.  Emacs shows the pair as quotation marks in a
  docstring; see (elisp) Documentation Tips.
- Use Emacs's word before a package term.  A package term is acceptable
  when Emacs has no concise word for the concept and the term is
  defined in "Core terms".
- The terms and rules that belong to another package — column-popup's
  column, popup buffer, popup window, origin, CP label and CPS — remain
  in that package's file.  This repository uses them only when it names
  that package or its behavior.
- The verification recipe is in `AGENTS.md`.  A change reports what was
  verified and what was not.
