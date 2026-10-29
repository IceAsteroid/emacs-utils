# emacs-utils

A personal collection of Emacs Lisp libraries and command files used in
a user's configuration.  The display action, the pivot, the window
test, the split options, the window prompt and the tab bar reader are
in their own repository:
`https://github.com/IceAsteroid/disbuf-pivot`.  The display
package is `disbuf-pivot`.  This repository keeps the
`ia/other-window-mru` command and the consult integration; the consult
integration requires the display package.

## Requirements

Emacs 31.1 is the tested version.  `emacs-utils.el` requires only
Emacs.  `layout/ia-window-utility.el` requires `ace-window`.
`layout/ia-tab-bar-modified-consult.el` requires `consult` and
`disbuf-pivot`; `avy` is required by `ace-window`.  The other
libraries require the packages their `require` forms name.

`emacs-utils.el` is the package main file; package.el reads only its
`Package-Requires` and `URL`.  The `Author`, `URL` and `SPDX` headers in
the layout files are comments.  The layout files name their dependencies
here and in their Commentary; package.el does not install them.

## Installation

Clone the repository and add its directories to `load-path`:

```elisp
(require 'emacs-utils)
(ia/emacs-utils-load-sub-dirs)
```

The consult integration also needs the display package on `load-path`:

```elisp
(add-to-list 'load-path "/path/to/disbuf-pivot")
(require 'ia-tab-bar-modified-consult)
(ia/tab-bar-modified-consult-mode +1)
```

`emacs-utils.el` adds the directories; it does not load a library or
enable a mode.  Require the library you need:

```elisp
(require 'ia-window-utility)
```

## The libraries

The directories hold libraries and command files: `appearance/`,
`buffer/`, `completion/`, `core/`, `doc-lookup/`, `info-inbox/`,
`layout/`, `org/` and `workaround/`.  The layout files are the
`ia/other-window-mru` command and the consult integration.  The display
action, pivot, window test, split options, window prompt and tab bar
reader are in `disbuf-pivot`.

## The tab prompt

`disbuf-pivot-tab-bar-read-tab-name` reads a tab name with
`completing-read`.  The display package's optional
`disbuf-pivot-tab-bar-consult` library supplies a consult
reader with previews and the
`disbuf-pivot-tab-bar-consult-mode` that installs it.  That
library deletes child frames before saving the window state and
preserves the minibuffer height while a preview selects a tab, so it
needs only consult and the display package.

`ia/tab-bar-modified-consult-mode` sets
`disbuf-pivot-tab-bar-read-function` to
`disbuf-pivot-tab-bar-consult-read-tab-name`, the display
package's reader, so the display action's tab prompt uses the same
consult reader as `ia/consult-tab-switch`.  The built-in tab overrides
and the rename advice call
`disbuf-pivot-tab-bar-consult-purge-child-frames`.  Disabling
the mode restores the previous read function; with the mode off, the
plain `completing-read` reader is used.

## Workarounds

`workaround/` holds one workaround per Emacs bug.  See
`workaround/README.md`.

## Checks

`make check` runs the library check, byte-compiles the core library, the
window command and the consult integration, and runs the buttercup tests
under `test/`.  `make checkdoc` reports the docstring findings.  The
consult integration needs the display package; the Makefile uses
`../disbuf-pivot`, or the directory named by
`DISPLAY_PACKAGE`.  The library check reads every `.el` file in the
feature directories and `emacs-utils.el`, then computes the libraries
from the `require` forms and checks for cycles.

The test tree mirrors the source directories that have tests:
`test/appearance/`, `test/buffer/`, `test/completion/`, `test/core/`,
`test/doc-lookup/` and `test/org/`.  The layout files are checked by
compile and checkdoc, not tests; the display tests are in
`disbuf-pivot`.  The `info-inbox/` and `workaround/`
directories have no tests.

## Conventions

The repository's terms, commit conventions and library rule are in
`TERM_AND_CONVENTION.md`.  The repository is licensed under
GPL-3.0-or-later; see `LICENSE`.
