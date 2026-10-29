# Changelog

## Unreleased

- Doc: the layout files name their optional dependencies in their
  Commentary and the README; only `emacs-utils.el` carries the package
  `Package-Requires`.
- Add: the load-path helper `emacs-utils.el`.
- Add: the core utility.
- Add: the buffer utilities.
- Add: the appearance utilities.
- Add: the completion utility.
- Add: the doc lookup utilities.
- Add: the info inbox utilities.
- Add: the Org utilities.
- Add: the window command.
- Add: the consult tab bar integration, which consumes the display
  package's optional `disbuf-pivot-tab-bar-consult` library,
  sets `disbuf-pivot-tab-bar-read-function` to its reader, and
  calls its child-frame cleanup for the built-in tab overrides.
- Fix: the display package's optional consult library supplies the
  consult reader with the child-frame cleanup and the minibuffer-height
  preservation, so the display action's tab prompt gets previews without
  `emacs-utils`.
- Add: the workarounds.
- Add: the tests.
- Doc: the README, the conventions and the agent instructions.
- Doc: the display package is `disbuf-pivot`; the consult
  integration consumes its `disbuf-pivot-tab-bar` reader and
  its optional consult reader.
