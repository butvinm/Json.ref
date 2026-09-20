REFAL_DIR := Refal-05-Standalone
REFAL05C  := $(REFAL_DIR)/bin/refal05c
R05PATH   := $(REFAL_DIR)/refal-05/lib:$(REFAL_DIR)/refal-5-framework/lib:$(REFAL_DIR)/refal-5-framework/lib/posix
R05CCOMP  ?= gcc -Wall -g

LIBS := LibraryEx Platform refal05rts refal05bif Go

.PHONY: all refal test test-basic test-parsing test-roundtrip clean distclean

all: example

refal: $(REFAL05C)

$(REFAL05C):
	git submodule update --init --recursive $(REFAL_DIR)
	$(MAKE) -C $(REFAL_DIR) bin/refal05c

example: example.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) example Json $(LIBS)

test/test_basic/run: test/test_basic/run.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_basic/run Json $(LIBS)

test/test_parsing/run: test/test_parsing/run.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_parsing/run Json $(LIBS)

test: test-basic test-parsing test-roundtrip

test-basic: test/test_basic/run
	./test/test_basic/test.sh

test-parsing: test/test_parsing/run
	./test/test_parsing/test.sh

# has no runner of its own, test_basic's one already does the round trip
test-roundtrip: test/test_basic/run
	./test/test_roundtrip/test.sh

clean:
	rm -rf example example.dSYM test/test_basic/run test/test_basic/run.dSYM test/test_parsing/run test/test_parsing/run.dSYM test/test_roundtrip/out *.c

distclean: clean
	$(MAKE) -C $(REFAL_DIR) clear
