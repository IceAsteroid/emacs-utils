# Run the checks for the personal collection and the library graph.  See AGENTS.md.

EMACS ?= emacs
ELPA ?= $(HOME)/.emacs.d/elpa
DISPLAY_PACKAGE ?= ../disbuf-pivot

ACE_WINDOW := $(firstword $(wildcard $(ELPA)/ace-window-*))
AVY := $(firstword $(wildcard $(ELPA)/avy-*))
CONSULT := $(firstword $(wildcard $(ELPA)/consult-*))

LOAD_PATH = -L core -L layout -L $(DISPLAY_PACKAGE) -L $(ACE_WINDOW) \
            -L $(AVY) -L $(CONSULT)

# The files `check-layers' reads: every library and command file in the
# feature directories.  The test, build and test-snippet files are not part
# of the graph.
FILES = emacs-utils.el \
        $(wildcard core/*.el) \
        $(wildcard layout/*.el) \
        $(wildcard appearance/*.el) \
        $(wildcard buffer/*.el) \
        $(wildcard completion/*.el) \
        $(wildcard doc-lookup/*.el) \
        $(wildcard info-inbox/*.el) \
        $(wildcard org/*.el) \
        $(wildcard workaround/*.el)

# The files `compile' and `checkdoc' read: the core library, the window
# command and the consult integration.
CHECK_FILES = core/ia-core-utility.el \
              layout/ia-window-utility.el \
              layout/ia-tab-bar-modified-consult.el

.PHONY: all check check-layers check-deps compile checkdoc test

all: check

check: check-layers compile test

check-layers:
	FILES='$(FILES)' $(EMACS) -Q --batch -l build/check-layers.el

check-deps:
	@for dir in "$(ACE_WINDOW)" "$(AVY)" "$(CONSULT)"; do \
		test -n "$$dir" || { \
			printf '%s\n' "missing a dependency under $(ELPA)"; exit 1; }; \
	done
	@test -d "$(DISPLAY_PACKAGE)" || { \
		printf '%s\n' "missing $(DISPLAY_PACKAGE)"; exit 1; }

compile: check-deps
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	cp $(CHECK_FILES) "$$tmp"/; \
	$(EMACS) -Q --batch -L "$$tmp" -L $(DISPLAY_PACKAGE) -L $(ACE_WINDOW) \
		-L $(AVY) -L $(CONSULT) -f batch-byte-compile "$$tmp"/*.el

checkdoc: check-deps
	@for file in $(CHECK_FILES); do \
		printf '== %s\n' "$$file"; \
		$(EMACS) -Q --batch $(LOAD_PATH) \
			--eval "(progn (require 'checkdoc) (checkdoc-file \"$$file\"))"; \
	done

test:
	eldev test
