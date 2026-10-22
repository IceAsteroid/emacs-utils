# Run the checks for the display layout files.  See AGENTS.md.

EMACS ?= emacs
ELPA ?= $(HOME)/.emacs.d/elpa

ACE_WINDOW := $(firstword $(wildcard $(ELPA)/ace-window-*))
AVY := $(firstword $(wildcard $(ELPA)/avy-*))
CONSULT := $(firstword $(wildcard $(ELPA)/consult-2*))

LOAD_PATH = -L layout -L $(ACE_WINDOW) -L $(AVY) -L $(CONSULT)

FILES = layout/ia-display-buffer-action.el \
        layout/ia-window-prefix-pivot.el \
        layout/ia-window-utility.el \
        layout/ia-tab-bar-modified.el \
        layout/ia-tab-bar-modified-consult.el

TESTS = test/ia-display-ask-test.el \
        test/ia-order-test.el \
        test/ia-tab-frame-test.el

.PHONY: all check check-deps compile checkdoc test

all: check

check: compile test

check-deps:
	@for dir in "$(ACE_WINDOW)" "$(AVY)" "$(CONSULT)"; do \
		test -n "$$dir" || { \
			echo "missing a dependency under $(ELPA)"; exit 1; }; \
	done

compile: check-deps
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	cp $(FILES) "$$tmp"/; \
	$(EMACS) -Q --batch -L "$$tmp" -L $(ACE_WINDOW) -L $(AVY) \
		-L $(CONSULT) -f batch-byte-compile "$$tmp"/*.el

checkdoc: check-deps
	@for file in $(FILES); do \
		echo "== $$file"; \
		$(EMACS) -Q --batch $(LOAD_PATH) \
			--eval "(progn (require 'checkdoc) (checkdoc-file \"$$file\"))"; \
	done

test: check-deps
	@set -e; for test in $(TESTS); do \
		echo "== $$test"; \
		$(EMACS) -Q --batch --eval "(setq load-prefer-newer t)" \
			$(LOAD_PATH) -l "$$test"; \
	done
