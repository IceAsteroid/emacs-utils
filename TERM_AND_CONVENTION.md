# emacs-utils — Terms and conventions

This file is the codification for this repository.  It binds every
change, including code, Commentary, docstrings, commit messages and the
replies that describe them.  The display package is a separate
repository; this file does not govern its terms.  A term is added to
"Core terms" with the
maintainer's agreement before it is used; a term that is dropped moves
to "Terms not used" with its replacement.  When this file and the code
disagree, report both sites and leave the fix until it is asked for.

## Core terms

Use Emacs's own name whenever Emacs has one.  The entries below are the
concepts this repository names; most of them are Emacs's, and each
entry says where Emacs defines it.

- **library** — a file another file loads with `require`.  Emacs
  calls a file loaded that way a library; see the (elisp) Loading node
  and `load-library`.  `make check-layers` computes the library files
  from the `require` forms.

A concept that is neither here nor named by Emacs: name the function or
option that implements it, rather than coining a noun.

## Terms not used

These forms are avoided in Commentary, docstrings, README, commit
messages and the replies that describe them.  Each entry gives the
phrasing to use instead.  A shell command, an identifier or a code
fragment is not prose and is not checked.

- adopt / adopted — describe the action: use, select or apply the
  thing, whichever is meant.
- session — say the call or the command, or "while the minibuffer is
  active", whichever is meant.
- echo — "echo area" is Emacs's term for the area where messages
  appear; use it rather than "the echo".  Identifiers keep the `echo`
  prefix, as Emacs does (`echo-keystrokes`).
- task context — delete the phrase, or say "the minibuffer".
- claim / claimed — say which thing does what: a window displays a
  buffer, a function returns a value, a mode installs a hook.
- stays / stayed — "remains / remained".
- summon / summoned — "display / displayed" for a buffer, "make / made"
  for a window, frame or tab.
- spawn / spawned / spawning — "make / made" for a window, frame or
  tab; "display / displayed" for a buffer.
- open a buffer / create a buffer — say "display a buffer in a window".
  A function that creates a buffer names `get-buffer-create`; the
  display rule never creates one.
- question, for the prompt of `completing-read` — say "prompt", or name
  the function that reads (`disbuf-pivot-tab-bar-read-tab-name`).  Emacs
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
  `ia/backward-kill-word`, not to its key.
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
- `CHANGELOG.md` is the repository-level incremental record.  Append an
  entry at the top of its `## Unreleased` section for a change a user of
  the utilities should know; the entry names the change, not a commit
  hash, because a rewrite changes hashes.  The commit message remains the
  atomic record of its change.
- A changelog entry names the file by its path relative to the
  repository root, and the public command or option it adds or changes.
  A leading slash is a filesystem absolute path and is not used.  The
  commit message carries the detail.
- In a changelog entry or an `Add:` body paragraph, a path directly
  after `Add:` means the change adds that file.  A change to a file
  that already exists states the behavior, option or command after the
  path, with `in` before it: `Add: in core/ia-core-utility.el,
  the `ia/feat-chunk` macro`.
- A release moves the entries under `## Unreleased` to a heading
  `## <version> - <date>` and leaves `## Unreleased` empty.  The
  version is the `Version` header of `emacs-utils.el`.
- A new coding or documentation standard is a forward fix: update the
  rule file and add a `Doc:` entry to `CHANGELOG.md`; do not rewrite past
  commits for the new standard.
- A file that another file requires is a library.  A library may define
  commands and modes; it must not enable or install them when it loads.
  Every repository file a library requires is a library too, and no
  library requires a file that requires it.  `make check-layers`
  computes the library files from the `require` forms among the files
  `FILES` names: a file another file requires is a library, a library
  requires only libraries, and the libraries do not require each other
  in a cycle.  A file that no other file requires may define commands
  and modes and may require libraries; a user's configuration that
  calls a library's functions does not change the list.
- Only the main file of a package carries `Package-Requires`.  A library
  that is not the package main file names its optional dependency in its
  Commentary and in `README.md`; a `Package-Requires` header there is not
  package metadata, and package.el ignores it.  `Author`, `URL` and
  `SPDX` headers in a library are comments; the main file's `URL` is
  package metadata.
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
  in Markdown and commit messages, e.g. `ia/ensure-substring`; in Emacs
  Lisp source use a grave accent before and an apostrophe after, e.g.
  `ia/ensure-substring'.  Emacs shows the pair as quotation marks in a
  docstring; see (elisp) Documentation Tips.
- Use Emacs's word before a package term.  A package term is acceptable
  when Emacs has no concise word for the concept and the term is
  defined in "Core terms".
- The verification recipe is in `AGENTS.md`.  A change reports what was
  verified and what was not.
