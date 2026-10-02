REFAL_DIR := Refal-05-Standalone
REFAL05C  := $(REFAL_DIR)/bin/refal05c
R05PATH   := $(REFAL_DIR)/refal-05/lib:$(REFAL_DIR)/refal-5-framework/lib:$(REFAL_DIR)/refal-5-framework/lib/posix
R05CCOMP  ?= gcc -Wall -g

LIBS := LibraryEx Platform refal05rts refal05bif Go

# every .ref file of test_basic is a separate test program
BASIC_TESTS := $(patsubst test/test_basic/%.ref,test/test_basic/bin/%,$(wildcard test/test_basic/*.ref))

.PHONY: all refal test test-basic test-stringify test-parsing test-python-compat clean distclean

all: example

refal: $(REFAL05C)

$(REFAL05C):
	git submodule update --init --recursive $(REFAL_DIR)
	$(MAKE) -C $(REFAL_DIR) bin/refal05c

example: example.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) example Json $(LIBS)

test/test_basic/bin/%: test/test_basic/%.ref Json.ref $(REFAL05C)
	mkdir -p $(@D)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_basic/$* Json $(LIBS)

test/test_stringify/run: test/test_stringify/run.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_stringify/run Json $(LIBS)

test/test_parsing/run: test/test_parsing/run.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_parsing/run Json $(LIBS)

test/test_python_compat/run: test/test_python_compat/run.ref Json.ref $(REFAL05C)
	R05CCOMP='$(R05CCOMP)' R05CFLAGS='-o $@' R05PATH='$(R05PATH)' $(REFAL05C) test/test_python_compat/run Json $(LIBS)

test: test-basic test-stringify test-parsing test-python-compat

test-basic: $(BASIC_TESTS)
	./test/test_basic/test.sh

test-stringify: test/test_stringify/run
	./test/test_stringify/test.sh

test-parsing: test/test_parsing/run
	./test/test_parsing/test.sh

test-python-compat: test/test_python_compat/run
	./test/test_python_compat/test.sh

clean:
	rm -rf example example.dSYM *.c \
		test/test_basic/bin \
		test/test_stringify/run test/test_stringify/run.dSYM test/test_stringify/out \
		test/test_parsing/run test/test_parsing/run.dSYM \
		test/test_python_compat/run test/test_python_compat/run.dSYM test/test_python_compat/out

distclean: clean
	$(MAKE) -C $(REFAL_DIR) clear
