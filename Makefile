# Settings
# --------

BUILD_DIR   := .build
DEFN_DIR    := $(BUILD_DIR)/defn
BUILD_LOCAL := $(CURDIR)/$(BUILD_DIR)/local

LIBRARY_PATH       := $(BUILD_LOCAL)/lib
C_INCLUDE_PATH     += :$(BUILD_LOCAL)/include
CPLUS_INCLUDE_PATH += :$(BUILD_LOCAL)/include
PKG_CONFIG_PATH    := $(LIBRARY_PATH)/pkgconfig

export LIBRARY_PATH
export C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH
export PKG_CONFIG_PATH

INSTALL_PREFIX := /usr/local
INSTALL_DIR    ?= $(DESTDIR)$(INSTALL_PREFIX)/bin

DEPS_DIR         := deps
K_SUBMODULE      := $(abspath $(DEPS_DIR)/k)
export PLUGIN_SUBMODULE := $(abspath $(DEPS_DIR)/plugin)

K_RELEASE := $(K_SUBMODULE)/k-distribution/target/release/k
K_BIN     := $(K_RELEASE)/bin
K_LIB     := $(K_RELEASE)/lib
export K_RELEASE

PATH := $(K_BIN):$(PATH)
export PATH

# need relative path for `pandoc` on MacOS
PANDOC_TANGLE_SUBMODULE := $(DEPS_DIR)/pandoc-tangle
TANGLER                 := $(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH                := $(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export TANGLER
export LUA_PATH

OPAM ?= opam

.PHONY: all clean clean-submodules distclean install uninstall                                                                                         \
        deps all-deps llvm-deps haskell-deps repo-deps k-deps ocaml-deps plugin-deps libsecp256k1 libff                                                \
        build build-all build-ocaml build-java build-node build-haskell build-llvm build-web3                                                          \
        defn java-defn ocaml-defn node-defn web3-defn haskell-defn llvm-defn                                                                           \
        split-tests                                                                                                                                    \
        test test-all test-conformance test-rest-conformance test-all-conformance test-slow-conformance test-failing-conformance                       \
        test-vm test-rest-vm test-all-vm test-bchain test-rest-bchain test-all-bchain                                                                  \
        test-web3 test-all-web3 test-failing-web3                                                                                                      \
        test-prove test-prove-benchmarks test-prove-functional test-prove-opcodes test-prove-erc20 test-prove-bihu test-prove-examples test-klab-prove \
        test-parse test-failure                                                                                                                        \
        test-interactive test-interactive-help test-interactive-run test-interactive-prove test-interactive-search test-interactive-firefly            \
        media media-pdf metropolis-theme
.SECONDARY:

all: build split-tests

clean:
	rm -rf $(DEFN_DIR)
	git clean -dfx -- tests/specs

distclean: clean
	rm -rf $(BUILD_DIR)

clean-submodules: distclean
	rm -rf $(DEPS_DIR)/k/make.timestamp $(DEPS_DIR)/metropolis/*.sty \
	       tests/ethereum-tests/make.timestamp $(DEPS_DIR)/plugin/make.timestamp  \
	       $(DEPS_DIR)/libff/build
	cd $(DEPS_DIR)/k         && mvn clean --quiet
	cd $(DEPS_DIR)/secp256k1 && $(MAKE) distclean || true

# Non-K Dependencies
# ------------------

libsecp256k1_out:=$(LIBRARY_PATH)/pkgconfig/libsecp256k1.pc
libff_out:=$(LIBRARY_PATH)/libff.a

libsecp256k1: $(libsecp256k1_out)
libff: $(libff_out)

$(DEPS_DIR)/secp256k1/autogen.sh:
	git submodule update --init --recursive -- $(DEPS_DIR)/secp256k1

$(libsecp256k1_out): $(DEPS_DIR)/secp256k1/autogen.sh
	cd $(DEPS_DIR)/secp256k1/ \
	    && ./autogen.sh \
	    && ./configure --enable-module-recovery --prefix="$(BUILD_LOCAL)" \
	    && $(MAKE) \
	    && $(MAKE) install

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
  LIBFF_CMAKE_FLAGS=
  LINK_PROCPS=-lprocps
else
  LIBFF_CMAKE_FLAGS=-DWITH_PROCPS=OFF
  LINK_PROCPS=
endif

LIBFF_CC ?=clang-8
LIBFF_CXX?=clang++-8

$(DEPS_DIR)/libff/CMakeLists.txt:
	git submodule update --init --recursive -- $(DEPS_DIR)/libff

$(libff_out): $(DEPS_DIR)/libff/CMakeLists.txt
	@mkdir -p $(DEPS_DIR)/libff/build
	cd $(DEPS_DIR)/libff/build \
	    && CC=$(LIBFF_CC) CXX=$(LIBFF_CXX) cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(BUILD_LOCAL) $(LIBFF_CMAKE_FLAGS) \
	    && make -s -j4 \
	    && make install

# K Dependencies
# --------------

deps: repo-deps
repo-deps: tangle-deps k-deps plugin-deps
k-deps: $(K_SUBMODULE)/make.timestamp
tangle-deps: $(TANGLER)
plugin-deps: $(PLUGIN_SUBMODULE)/make.timestamp

ifneq ($(RELEASE),)
K_BUILD_TYPE         := Release
SEMANTICS_BUILD_TYPE := Release
KOMPILE_OPTS         += --iterated
else
K_BUILD_TYPE         := FastBuild
SEMANTICS_BUILD_TYPE := Debug
endif

$(K_SUBMODULE)/make.timestamp:
	git submodule update --init --recursive -- $(K_SUBMODULE)
	cd $(K_SUBMODULE) && mvn package -DskipTests -U -Dproject.build.type=${K_BUILD_TYPE}
	touch $(K_SUBMODULE)/make.timestamp

$(TANGLER):
	git submodule update --init -- $(PANDOC_TANGLE_SUBMODULE)

$(PLUGIN_SUBMODULE)/make.timestamp:
	git submodule update --init --recursive -- $(PLUGIN_SUBMODULE)
	touch $(PLUGIN_SUBMODULE)/make.timestamp

ocaml-deps:
	eval $$($(OPAM) config env) \
	    $(OPAM) install --yes mlgmp zarith uuidm cryptokit secp256k1.0.3.2 bn128 ocaml-protoc rlp yojson hex ocp-ocamlres

# Building
# --------

MAIN_MODULE    := ETHEREUM-SIMULATION
SYNTAX_MODULE  := $(MAIN_MODULE)
export MAIN_DEFN_FILE := driver

k_files       := driver.k data.k network.k evm.k krypto.k edsl.k edsl2.k evm-node.k web3.k asm.k state-loader.k
EXTRA_K_FILES += $(MAIN_DEFN_FILE).k
ALL_K_FILES   := $(k_files) $(EXTRA_K_FILES)

ocaml_dir   := $(DEFN_DIR)/ocaml
llvm_dir    := $(DEFN_DIR)/llvm
java_dir    := $(DEFN_DIR)/java
haskell_dir := $(DEFN_DIR)/haskell
export node_dir    := $(CURDIR)/$(DEFN_DIR)/node
export web3_dir    := $(CURDIR)/$(DEFN_DIR)/web3

ocaml_files   := $(patsubst %, $(ocaml_dir)/%, $(ALL_K_FILES))
llvm_files    := $(patsubst %, $(llvm_dir)/%, $(ALL_K_FILES))
java_files    := $(patsubst %, $(java_dir)/%, $(ALL_K_FILES))
haskell_files := $(patsubst %, $(haskell_dir)/%, $(ALL_K_FILES))
node_files    := $(patsubst %, $(node_dir)/%, $(ALL_K_FILES))
web3_files    := $(patsubst %, $(web3_dir)/%, $(ALL_K_FILES))
defn_files    := $(ocaml_files) $(llvm_file) $(java_files) $(haskell_files) $(node_files) $(web3_files)

ocaml_kompiled   := $(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled/interpreter
java_kompiled    := $(java_dir)/$(MAIN_DEFN_FILE)-kompiled/timestamp
node_kompiled    := $(DEFN_DIR)/vm/kevm-vm
web3_kompiled    := $(web3_dir)/build/kevm-client
haskell_kompiled := $(haskell_dir)/$(MAIN_DEFN_FILE)-kompiled/definition.kore
llvm_kompiled    := $(llvm_dir)/$(MAIN_DEFN_FILE)-kompiled/interpreter

# Tangle definition from *.md files

concrete_tangle := .k:not(.node):not(.symbolic):not(.nobytes),.standalone,.concrete,.bytes
java_tangle     := .k:not(.node):not(.concrete):not(.bytes),.standalone,.symbolic,.nobytes
haskell_tangle  := .k:not(.node):not(.concrete):not(.nobytes),.standalone,.symbolic,.bytes
node_tangle     := .k:not(.standalone):not(.symbolic):not(.nobytes),.node,.concrete,.bytes

defn: $(defn_files)
ocaml-defn:   $(ocaml_files)
llvm-defn:    $(llvm_files)
java-defn:    $(java_files)
haskell-defn: $(haskell_files)
node-defn:    $(node_files)
web3-defn:    $(web3_files)

$(ocaml_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(ocaml_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(concrete_tangle)" $< > $@

$(llvm_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(llvm_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(concrete_tangle)" $< > $@

$(java_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(java_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(java_tangle)" $< > $@

$(haskell_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(haskell_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(haskell_tangle)" $< > $@

$(node_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(node_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(node_tangle)" $< > $@

$(web3_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(web3_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(concrete_tangle)" $< > $@

# Kompiling

KOMPILE_OPTS      :=
LLVM_KOMPILE_OPTS :=

build: build-llvm build-haskell build-java build-web3 build-node
build-all: build build-ocaml
build-ocaml:   $(ocaml_kompiled)
build-java:    $(java_kompiled)
build-node:    $(node_kompiled)
build-web3:    $(web3_kompiled)
build-haskell: $(haskell_kompiled)
build-llvm:    $(llvm_kompiled)

# Java Backend

$(java_kompiled): $(java_files)
	$(K_BIN)/kompile --debug --main-module $(MAIN_MODULE) --backend java \
	                 --syntax-module $(SYNTAX_MODULE) $(java_dir)/$(MAIN_DEFN_FILE).k \
	                 --directory $(java_dir) -I $(java_dir) \
	                 $(KOMPILE_OPTS)

# Haskell Backend

$(haskell_kompiled): $(haskell_files)
	$(K_BIN)/kompile --debug --main-module $(MAIN_MODULE) --backend haskell --hook-namespaces KRYPTO \
	                 --syntax-module $(SYNTAX_MODULE) $(haskell_dir)/$(MAIN_DEFN_FILE).k \
	                 --directory $(haskell_dir) -I $(haskell_dir) \
	                 $(KOMPILE_OPTS)

# OCAML Backend

ifeq ($(BYTE),yes)
  EXT=cmo
  LIBEXT=cma
  DLLEXT=cma
  OCAMLC=c
  LIBFLAG=-a
else
  EXT=cmx
  LIBEXT=cmxa
  DLLEXT=cmxs
  OCAMLC=opt -O3
  LIBFLAG=-shared
endif

$(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled/constants.$(EXT): $(ocaml_files)
	eval $$($(OPAM) config env) \
	    && $(K_BIN)/kompile --debug --main-module $(MAIN_MODULE) --backend ocaml \
	                        --syntax-module $(SYNTAX_MODULE) $(ocaml_dir)/$(MAIN_DEFN_FILE).k \
	                        --hook-namespaces "KRYPTO" --gen-ml-only -O3 --non-strict \
	                        --directory $(ocaml_dir) -I $(ocaml_dir) $(KOMPILE_OPTS) \
	    && cd $(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled \
	    && ocamlfind $(OCAMLC) -c -g constants.ml -package gmp -package zarith -safe-string

$(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin/semantics.$(LIBEXT): $(wildcard $(PLUGIN_SUBMODULE)/plugin/*.ml $(PLUGIN_SUBMODULE)/plugin/*.mli) $(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled/constants.$(EXT)
	@mkdir -p $(dir $@)
	cp $(PLUGIN_SUBMODULE)/plugin/*.ml $(PLUGIN_SUBMODULE)/plugin/*.mli $(dir $@)
	eval $$($(OPAM) config env) \
	    && ocp-ocamlres -format ocaml $(PLUGIN_SUBMODULE)/plugin/proto/VERSION -o $(dir $@)/apiVersion.ml \
	    && ocaml-protoc $(PLUGIN_SUBMODULE)/plugin/proto/*.proto -ml_out $(dir $@) \
	    && cd $(dir $@) \
	        && ocamlfind $(OCAMLC) -c -g -I $(CURDIR)/$(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled \
	                               KRYPTO.ml \
	                               -package cryptokit -package hex -package secp256k1 -package bn128 -package ocaml-protoc -safe-string -thread \
	        && ocamlfind $(OCAMLC) -a -o semantics.$(LIBEXT) KRYPTO.$(EXT) -thread \
	        && ocamlfind remove ethereum-semantics-plugin-ocaml \
	        && ocamlfind install ethereum-semantics-plugin-ocaml $(PLUGIN_SUBMODULE)/plugin/META semantics.* *.cmi *.$(EXT)

$(ocaml_kompiled): $(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin/semantics.$(LIBEXT)
	eval $$($(OPAM) config env) \
	    && cd $(ocaml_dir)/$(MAIN_DEFN_FILE)-kompiled \
	        && ocamllex lexer.mll \
	        && ocamlyacc parser.mly \
	        && ocamlfind $(OCAMLC) -c -g -package gmp -package zarith -package uuidm -safe-string prelude.ml plugin.ml parser.mli parser.ml lexer.ml hooks.ml run.ml -thread \
	        && ocamlfind $(OCAMLC) -c -g -w -11-26 -package gmp -package zarith -package uuidm -package ethereum-semantics-plugin-ocaml -safe-string realdef.ml -match-context-rows 2 \
	        && ocamlfind $(OCAMLC) $(LIBFLAG) -o realdef.$(DLLEXT) realdef.$(EXT) \
	        && ocamlfind $(OCAMLC) -g -o interpreter constants.$(EXT) prelude.$(EXT) plugin.$(EXT) parser.$(EXT) lexer.$(EXT) hooks.$(EXT) run.$(EXT) interpreter.ml \
	                               -package gmp -package hex -package dynlink -package zarith -package str -package uuidm -package unix -package ethereum-semantics-plugin-ocaml -linkpkg -linkall -thread -safe-string

# Node Backend

$(node_kompiled): MAIN_DEFN_FILE=evm-node
$(node_kompiled): MAIN_MODULE=EVM-NODE
$(node_kompiled): SYNTAX_MODULE=EVM-NODE

$(node_dir)/$(MAIN_DEFN_FILE)-kompiled/definition.kore: $(node_files)
	$(K_BIN)/kompile --debug --main-module $(MAIN_MODULE) --backend llvm \
	                 --syntax-module $(SYNTAX_MODULE) $(node_dir)/$(MAIN_DEFN_FILE).k \
	                 --directory $(node_dir) -I $(node_dir) -I $(node_dir) \
	                 --hook-namespaces "KRYPTO BLOCKCHAIN" \
	                 --no-llvm-kompile \
	                 $(KOMPILE_OPTS)

$(node_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin/proto/msg.pb.cc: $(PLUGIN_SUBMODULE)/plugin/proto/msg.proto
	@mkdir -p $(node_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin
	protoc --cpp_out=$(node_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin -I $(PLUGIN_SUBMODULE)/plugin $(PLUGIN_SUBMODULE)/plugin/proto/msg.proto

.PHONY: $(node_kompiled)
$(node_kompiled): $(node_dir)/$(MAIN_DEFN_FILE)-kompiled/definition.kore $(node_dir)/$(MAIN_DEFN_FILE)-kompiled/plugin/proto/msg.pb.cc $(libff_out)
	@mkdir -p $(DEFN_DIR)/vm
	cd $(DEFN_DIR)/vm && cmake $(CURDIR)/cmake/node -DCMAKE_BUILD_TYPE=${SEMANTICS_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} && $(MAKE)

# Web3 Backend

$(web3_dir)/web3-kompiled/definition.kore: $(web3_files)
	$(K_BIN)/kompile --debug --main-module WEB3 --backend llvm \
	                 --syntax-module WEB3 $(web3_dir)/web3.k \
	                 --directory $(web3_dir) -I $(web3_dir) \
	                 --hook-namespaces "KRYPTO JSON" \
	                 --no-llvm-kompile \
	                 $(KOMPILE_OPTS)

.PHONY: $(web3_kompiled)
$(web3_kompiled): $(web3_dir)/web3-kompiled/definition.kore $(libff_out)
	@mkdir -p $(web3_dir)/build
	cd $(web3_dir)/build && cmake $(CURDIR)/cmake/client -DCMAKE_BUILD_TYPE=${SEMANTICS_BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} && $(MAKE)

# LLVM Backend

$(llvm_kompiled): $(llvm_files) $(libff_out)
	$(K_BIN)/kompile --debug --main-module $(MAIN_MODULE) --backend llvm \
	                 --syntax-module $(SYNTAX_MODULE) $(llvm_dir)/$(MAIN_DEFN_FILE).k \
	                 --directory $(llvm_dir) -I $(llvm_dir) -I $(llvm_dir) \
	                 --hook-namespaces KRYPTO \
	                 $(KOMPILE_OPTS) \
	                 -ccopt $(PLUGIN_SUBMODULE)/plugin-c/crypto.cpp \
	                 -ccopt -g -ccopt -std=c++14 -ccopt -O2 \
	                 -ccopt -L$(LIBRARY_PATH) \
	                 -ccopt -lff -ccopt -lcryptopp -ccopt -lsecp256k1 $(addprefix -ccopt ,$(LINK_PROCPS))

# Installing
# ----------

KEVM_RELEASE_TAG?=

install: $(INSTALL_DIR)/$(notdir $(node_kompiled))
$(INSTALL_DIR)/$(notdir $(node_kompiled)): $(node_kompiled)
	cd $(DEFN_DIR)/vm && $(MAKE) install

uninstall:
	rm $(INSTALL_DIR)/$(notdir $(node_kompiled))

release.md: INSTALL.md
	echo "KEVM Release $(KEVM_RELEASE_TAG)"  > $@
	echo                                    >> $@
	cat INSTALL.md                          >> $@

# Tests
# -----

TEST_CONCRETE_BACKEND := llvm
TEST_SYMBOLIC_BACKEND := java

TEST         := ./kevm
TEST_OPTIONS :=
CHECK        := git --no-pager diff --no-index --ignore-all-space -R

KEVM_MODE     := NORMAL
KEVM_SCHEDULE := PETERSBURG

KEVM_WEB3_ARGS := --shutdownable

KPROVE_MODULE  := VERIFICATION
KPROVE_OPTIONS :=

test-all: test-all-conformance test-prove test-interactive test-parse
test: test-conformance test-prove test-interactive test-parse

split-tests: tests/ethereum-tests/make.timestamp

tests/%/make.timestamp:
	git submodule update --init -- tests/$*
	touch $@

# Generic Test Harnesses

tests/ethereum-tests/VMTests/%: KEVM_MODE=VMTESTS
tests/ethereum-tests/VMTests/%: KEVM_SCHEDULE=DEFAULT

tests/%.run: tests/%
	MODE=$(KEVM_MODE) SCHEDULE=$(KEVM_SCHEDULE)                                                                        \
	    $(TEST) interpret $(TEST_OPTIONS) --backend $(TEST_CONCRETE_BACKEND)                                           \
	    $< > tests/$*.$(TEST_CONCRETE_BACKEND)-out                                                                     \
	    || $(CHECK) tests/$*.$(TEST_CONCRETE_BACKEND)-out tests/templates/output-success-$(TEST_CONCRETE_BACKEND).json
	rm -rf tests/$*.$(TEST_CONCRETE_BACKEND)-out

tests/%.run-interactive: tests/%
	MODE=$(KEVM_MODE) SCHEDULE=$(KEVM_SCHEDULE)                                                                        \
	    $(TEST) run $(TEST_OPTIONS) --backend $(TEST_CONCRETE_BACKEND)                                                 \
	    $< > tests/$*.$(TEST_CONCRETE_BACKEND)-out                                                                     \
	    || $(CHECK) tests/$*.$(TEST_CONCRETE_BACKEND)-out tests/templates/output-success-$(TEST_CONCRETE_BACKEND).json
	rm -rf tests/$*.$(TEST_CONCRETE_BACKEND)-out

tests/%.run-expected: tests/% tests/%.expected
	MODE=$(KEVM_MODE) SCHEDULE=$(KEVM_SCHEDULE)                                                                        \
	    $(TEST) run $(TEST_OPTIONS) --backend $(TEST_CONCRETE_BACKEND)                                                 \
	    $< > tests/$*.$(TEST_CONCRETE_BACKEND)-out                                                                     \
	    || $(CHECK) tests/$*.$(TEST_CONCRETE_BACKEND)-out tests/$*.expected
	rm -rf tests/$*.$(TEST_CONCRETE_BACKEND)-out

tests/web3/no-shutdown/%: KEVM_WEB3_ARGS=

tests/%.run-web3: tests/%.in.json
	tests/web3/runtest.sh $< tests/$*.out.json $(KEVM_WEB3_ARGS)
	$(CHECK) tests/$*.out.json tests/$*.expected.json
	rm -rf tests/$*.out.json

tests/%.parse: tests/%
	$(TEST) kast $(TEST_OPTIONS) --backend $(TEST_CONCRETE_BACKEND) $< kast > $@-out
	$(CHECK) $@-out $@-expected
	rm -rf $@-out

tests/specs/functional/%.prove: TEST_SYMBOLIC_BACKEND=haskell
tests/specs/functional/storageRoot-spec.k.prove: TEST_SYMBOLIC_BACKEND=java

tests/%.prove: tests/%
	$(TEST) prove $(TEST_OPTIONS) --backend $(TEST_SYMBOLIC_BACKEND) $< --format-failures --def-module $(KPROVE_MODULE) $(KPROVE_OPTIONS) \
	    --concrete-rules $(shell cat $(dir $@)concrete-rules.txt | tr '\n' ',')

tests/%.search: tests/%
	$(TEST) search $(TEST_OPTIONS) --backend $(TEST_SYMBOLIC_BACKEND) $< "<statusCode> EVMC_INVALID_INSTRUCTION </statusCode>" > $@-out
	$(CHECK) $@-out $@-expected
	rm -rf $@-out

tests/%.klab-prove: tests/%
	$(TEST) klab-prove $(TEST_OPTIONS) --backend $(TEST_SYMBOLIC_BACKEND) $< --format-failures --def-module $(KPROVE_MODULE) $(KPROVE_OPTIONS) \
	    --concrete-rules $(shell cat $(dir $@)concrete-rules.txt | tr '\n' ',')

# Smoke Tests

smoke_tests_run=tests/ethereum-tests/VMTests/vmArithmeticTest/add0.json \
                tests/ethereum-tests/VMTests/vmIOandFlowOperations/pop1.json \
                tests/interactive/sumTo10.evm

smoke_tests_prove=tests/specs/erc20/ds/transfer-failure-1-a-spec.k

# Conformance Tests

tests/ethereum-tests/%.json: tests/ethereum-tests/make.timestamp

slow_conformance_tests    = $(shell cat tests/slow.$(TEST_CONCRETE_BACKEND))    # timeout after 20s
failing_conformance_tests = $(shell cat tests/failing.$(TEST_CONCRETE_BACKEND))

test-all-conformance: test-all-vm test-all-bchain
test-rest-conformance: test-rest-vm test-rest-bchain
test-slow-conformance: $(slow_conformance_tests:=.run)
test-failing-conformance: $(failing_conformance_tests:=.run)
test-conformance: test-vm test-bchain

all_vm_tests     = $(wildcard tests/ethereum-tests/VMTests/*/*.json)
quick_vm_tests   = $(filter-out $(slow_conformance_tests), $(all_vm_tests))
passing_vm_tests = $(filter-out $(failing_conformance_tests), $(quick_vm_tests))
rest_vm_tests    = $(filter-out $(passing_vm_tests), $(all_vm_tests))

test-all-vm: $(all_vm_tests:=.run)
test-rest-vm: $(rest_vm_tests:=.run)
test-vm: $(passing_vm_tests:=.run)

all_bchain_tests     = $(wildcard tests/ethereum-tests/BlockchainTests/GeneralStateTests/*/*.json)                            \
                       $(wildcard tests/ethereum-tests/LegacyTests/Constantinople/BlockchainTests/GeneralStateTests/*/*.json)
quick_bchain_tests   = $(filter-out $(slow_conformance_tests), $(all_bchain_tests))
passing_bchain_tests = $(filter-out $(failing_conformance_tests), $(quick_bchain_tests))
rest_bchain_tests    = $(filter-out $(passing_bchain_tests), $(all_bchain_tests))

test-all-bchain: $(all_bchain_tests:=.run)
test-rest-bchain: $(rest_bchain_tests:=.run)
test-bchain: $(passing_bchain_tests:=.run)

all_web3_tests     = $(wildcard tests/web3/*.in.json) $(wildcard tests/web3/*/*.in.json)
failing_web3_tests = $(shell cat tests/failing.web3)
passing_web3_tests = $(filter-out $(failing_web3_tests), $(all_web3_tests))

test-all-web3: $(all_web3_tests:.in.json=.run-web3)
test-failing-web3: $(failing_web3_tests:.in.json=.run-web3)
test-web3: $(passing_web3_tests:.in.json=.run-web3)

# Proof Tests

prove_specs_dir        := tests/specs
prove_failing_tests    := $(shell cat $(prove_specs_dir)/failing)
prove_benchmarks_tests := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/benchmarks/*-spec.k))
prove_functional_tests := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/functional/*-spec.k))
prove_opcodes_tests    := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/opcodes/*-spec.k))
prove_erc20_tests      := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/erc20/*/*-spec.k))
prove_bihu_tests       := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/bihu/*-spec.k))
prove_examples_tests   := $(filter-out $(prove_failing_tests), $(wildcard $(prove_specs_dir)/examples/*-spec.k))

test-prove: test-prove-benchmarks test-prove-functional test-prove-opcodes test-prove-erc20 test-prove-bihu test-prove-examples
test-prove-benchmarks: $(prove_benchmarks_tests:=.prove)
test-prove-functional: $(prove_functional_tests:=.prove)
test-prove-opcodes:    $(prove_opcodes_tests:=.prove)
test-prove-erc20:      $(prove_erc20_tests:=.prove)
test-prove-bihu:       $(prove_bihu_tests:=.prove)
test-prove-examples:   $(prove_examples_tests:=.prove)

test-klab-prove: $(smoke_tests_prove:=.klab-prove)

# Parse Tests

parse_tests:=$(wildcard tests/interactive/*.json) \
             $(wildcard tests/interactive/*.evm)

test-parse: $(parse_tests:=.parse)
	echo $(parse_tests)

# Failing correctly tests

failure_tests:=$(wildcard tests/failing/*.json)

test-failure: $(failure_tests:=.run-expected)

# Interactive Tests

test-interactive: test-interactive-run test-interactive-prove test-interactive-search test-interactive-help

test-interactive-run: $(smoke_tests_run:=.run-interactive)
test-interactive-prove: $(smoke_tests_prove:=.prove)

search_tests:=$(wildcard tests/interactive/search/*.evm)
test-interactive-search: $(search_tests:=.search)

test-interactive-help:
	$(TEST) help

# Notice that `npm install` comes after `npx kevm-ganache-cli` to allow time for it to start up.
test-interactive-firefly:
	./tests/node-firefly

# Media
# -----

media: media-pdf

### Media generated PDFs

media_pdfs := 201710-presentation-devcon3                          \
              201801-presentation-csf                              \
              201905-exercise-k-workshop                           \
              201908-trufflecon-workshop 201908-trufflecon-firefly

media/%.pdf: media/%.md media/citations.md
	@mkdir -p $(dir $@)
	cat $^ | pandoc --from markdown --filter pandoc-citeproc --to beamer --output $@

media-pdf: $(patsubst %, media/%.pdf, $(media_pdfs))

metropolis-theme: $(BUILD_DIR)/media/metropolis/beamerthememetropolis.sty

$(BUILD_DIR)/media/metropolis/beamerthememetropolis.sty:
	git submodule update --init -- $(dir $@)
	cd $(dir $@) && $(MAKE)

