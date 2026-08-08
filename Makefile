# (fab) — build fab binary
#
# Usage:
#   make          # build fab binary
#   make clean

LISP  ?= sbcl
BUILD  = build

.PHONY: all clean

all: $(BUILD)/fab

$(BUILD)/fab: src/*.lisp fab.asd
	mkdir -p $(BUILD)
	$(LISP) --non-interactive \
	  --eval '(require :asdf)' \
	  --eval '(asdf:load-system :fab)' \
	  --eval '(ensure-directories-exist #p"$(BUILD)/fab")' \
	  --eval '(asdf:make "fab")'

clean:
	rm -rf $(BUILD)
