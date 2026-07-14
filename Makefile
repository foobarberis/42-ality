.DEFAULT_GOAL := all

NAME = ft_ality
BYTE = $(NAME).byte
SRCDIR = src
BUILDDIR = _build
DEPSDIR = .deps
LOCALDIR = .local
SDL_PREFIX = $(abspath $(LOCALDIR)/sdl)
SDL2_VERSION = 2.32.8
SDL12_VERSION = 1.2.76
SDL2_ARCHIVE = $(DEPSDIR)/SDL2-$(SDL2_VERSION).tar.gz
SDL12_ARCHIVE = $(DEPSDIR)/sdl12-compat-$(SDL12_VERSION).tar.gz
SDL2_SRC = $(DEPSDIR)/SDL2-$(SDL2_VERSION)
SDL12_SRC = $(DEPSDIR)/sdl12-compat-$(SDL12_VERSION)
SDL2_BUILD = $(DEPSDIR)/build-sdl2
SDL12_BUILD = $(DEPSDIR)/build-sdl12-compat
SDL2_STAMP = $(SDL2_BUILD)/installed
SDL_CONFIG = $(SDL_PREFIX)/bin/sdl-config
UNIT = $(BUILDDIR)/test_unit.byte
UNIT_OBJ = $(BUILDDIR)/test_support.cmo \
		   $(BUILDDIR)/test_parse.cmo \
		   $(BUILDDIR)/test_validate.cmo \
		   $(BUILDDIR)/test_training.cmo \
		   $(BUILDDIR)/test_execution.cmo

MODULES = automaton_sig automaton parse validate training execution keyboard ft_ality
SRC_ML = $(addprefix $(SRCDIR)/,$(addsuffix .ml,$(MODULES)))
TEST_ML = test/test_support.ml \
		  test/test_parse.ml \
		  test/test_validate.ml \
		  test/test_training.ml \
		  test/test_execution.ml

NATIVE_OBJ = $(addprefix $(BUILDDIR)/,$(addsuffix .cmx,$(MODULES)))
BYTE_OBJ = $(addprefix $(BUILDDIR)/,$(addsuffix .cmo,$(MODULES)))
DEPFILE = $(BUILDDIR)/depend.mk

SWITCH = .
OCAML_VERSION = 4.14.2
FIND_PACKAGES = sdl
OPAM_PACKAGES = ocamlfind ocamlsdl
SDL_ENV = PATH=$(SDL_PREFIX)/bin:$$PATH PKG_CONFIG_PATH=$(SDL_PREFIX)/lib/pkgconfig:$$PKG_CONFIG_PATH CMAKE_PREFIX_PATH=$(SDL_PREFIX):$$CMAKE_PREFIX_PATH DYLD_LIBRARY_PATH=$(SDL_PREFIX)/lib:$$DYLD_LIBRARY_PATH LD_LIBRARY_PATH=$(SDL_PREFIX)/lib:$$LD_LIBRARY_PATH
RUN = mise exec -- env $(SDL_ENV) opam exec --switch=$(SWITCH) --
PKG = $(addprefix -package ,$(FIND_PACKAGES))
SDL_LDFLAGS = $$($(SDL_CONFIG) --libs | sed 's/ / -cclib /g; s/^/-cclib /')
OCAMLFLAGS = -g -I $(BUILDDIR)
DEPFLAGS = -I $(SRCDIR)

ifneq ($(filter clean fclean distclean setup,$(MAKECMDGOALS)),)
SKIP_DEPS = 1
endif

ifneq ($(SKIP_DEPS),1)
-include $(DEPFILE)
endif

all: $(NAME)

byte: $(BYTE)

tools:
	@mise install

$(DEPSDIR):
	@mkdir -p $@

$(SDL2_ARCHIVE): | $(DEPSDIR) tools
	@curl -L --fail --silent --show-error -o $@ \
		https://github.com/libsdl-org/SDL/releases/download/release-$(SDL2_VERSION)/SDL2-$(SDL2_VERSION).tar.gz
	@echo "0ca83e9c9b31e18288c7ec811108e58bac1f1bb5ec6577ad386830eac51c787e  $@" | shasum -a 256 -c -

$(SDL12_ARCHIVE): | $(DEPSDIR) tools
	@curl -L --fail --silent --show-error -o $@ \
		https://github.com/libsdl-org/sdl12-compat/releases/download/release-$(SDL12_VERSION)/sdl12-compat-$(SDL12_VERSION).tar.gz
	@echo "a68477009c24bc6e876326b1e8dd0bedec2b0c37acbddbddf90acba48fba4b38  $@" | shasum -a 256 -c -

$(SDL2_SRC)/CMakeLists.txt: $(SDL2_ARCHIVE)
	@rm -rf $(SDL2_SRC)
	@tar -xzf $< -C $(DEPSDIR)

$(SDL12_SRC)/CMakeLists.txt: $(SDL12_ARCHIVE)
	@rm -rf $(SDL12_SRC)
	@tar -xzf $< -C $(DEPSDIR)

$(SDL2_STAMP): $(SDL2_SRC)/CMakeLists.txt | tools
	@rm -rf $(SDL2_BUILD)
	@mise exec -- cmake -S $(SDL2_SRC) -B $(SDL2_BUILD) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(SDL_PREFIX) \
		-DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF
	@mise exec -- cmake --build $(SDL2_BUILD)
	@mise exec -- cmake --install $(SDL2_BUILD)
	@touch $@

$(SDL_CONFIG): $(SDL12_SRC)/CMakeLists.txt $(SDL2_STAMP) | tools
	@perl -0pi.bak -e 's/\@SDL_RLD_FLAGS\@/-Wl,-rpath,\$${libdir} \@SDL_RLD_FLAGS\@/' $(SDL12_SRC)/sdl-config.in
	@rm -rf $(SDL12_BUILD)
	@mise exec -- cmake -S $(SDL12_SRC) -B $(SDL12_BUILD) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(SDL_PREFIX) \
		-DCMAKE_PREFIX_PATH=$(SDL_PREFIX) \
		-DSDL12TESTS=OFF
	@mise exec -- cmake --build $(SDL12_BUILD)
	@mise exec -- cmake --install $(SDL12_BUILD)
	@test -x $@

setup: $(SDL_CONFIG)
	@mise exec -- opam init --disable-sandboxing --bare -y >/dev/null 2>&1 || true
	@if [ -d _opam ] && [ "$$(mise exec -- opam var --switch=$(SWITCH) ocaml:version 2>/dev/null)" != "$(OCAML_VERSION)" ]; then rm -rf _opam; fi
	@if [ ! -d _opam ]; then mise exec -- opam switch create $(SWITCH) ocaml-base-compiler.$(OCAML_VERSION) -y; fi
	@$(SDL_ENV) mise exec -- opam install --switch=$(SWITCH) -y --assume-depexts $(OPAM_PACKAGES)

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

$(DEPFILE): $(SRC_ML) Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamldep $(PKG) $(DEPFLAGS) $(SRC_ML) | \
		sed \
			-e 's#^$(SRCDIR)/\([^ ]*\)\.cmo:#$(BUILDDIR)/\1.cmo:#' \
			-e 's#^$(SRCDIR)/\([^ ]*\)\.cmx:#$(BUILDDIR)/\1.cmx:#' \
			-e 's#$(SRCDIR)/\([^ ]*\)\.cmo#$(BUILDDIR)/\1.cmo#g' \
			-e 's#$(SRCDIR)/\([^ ]*\)\.cmx#$(BUILDDIR)/\1.cmx#g' > $@

$(BUILDDIR)/%.cmx: $(SRCDIR)/%.ml Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlopt $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/%.cmo: $(SRCDIR)/%.ml Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_support.cmo: test/test_support.ml Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_parse.cmo: test/test_parse.ml $(BUILDDIR)/test_support.cmo Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_validate.cmo: test/test_validate.ml $(BUILDDIR)/test_support.cmo Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_training.cmo: test/test_training.ml $(BUILDDIR)/test_support.cmo Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_execution.cmo: test/test_execution.ml $(BUILDDIR)/test_support.cmo Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(NAME): $(NATIVE_OBJ)
	$(RUN) ocamlfind ocamlopt $(OCAMLFLAGS) $(PKG) -linkpkg $(SDL_LDFLAGS) $^ -o $@

$(BYTE): $(BYTE_OBJ)
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -linkpkg $(SDL_LDFLAGS) $^ -o $@

$(UNIT): $(BUILDDIR)/automaton.cmo $(BUILDDIR)/parse.cmo $(BUILDDIR)/validate.cmo $(BUILDDIR)/training.cmo $(BUILDDIR)/execution.cmo $(UNIT_OBJ)
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $^ -o $@

unit ut: $(UNIT)
	@$(RUN) ./$(UNIT)

e2e:
	@echo "No end-to-end tests yet"

test: unit e2e

clean:
	@rm -rf $(BUILDDIR)

fclean: clean
	@rm -f $(NAME) $(BYTE)

re: fclean all

distclean: fclean
	@rm -rf _opam $(DEPSDIR) $(LOCALDIR)

.PHONY: all byte tools setup unit ut e2e test clean fclean re distclean
