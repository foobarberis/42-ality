.DEFAULT_GOAL := all

NAME = ft_ality
BYTE = $(NAME).byte
SRCDIR = src
BUILDDIR = _build
UNIT = $(BUILDDIR)/test_unit.byte
UNIT_OBJ = $(BUILDDIR)/test_parse.cmo \
		   $(BUILDDIR)/test_validate.cmo

MODULES = automaton_sig automaton parse validate training ft_ality
SRC_ML = $(addprefix $(SRCDIR)/,$(addsuffix .ml,$(MODULES)))
TEST_ML = test/test_parse.ml \
		  test/test_validate.ml

NATIVE_OBJ = $(addprefix $(BUILDDIR)/,$(addsuffix .cmx,$(MODULES)))
BYTE_OBJ = $(addprefix $(BUILDDIR)/,$(addsuffix .cmo,$(MODULES)))
DEPFILE = $(BUILDDIR)/depend.mk

SWITCH = .
OCAML_VERSION = 5.2.1
FIND_PACKAGES =
OPAM_PACKAGES =

RUN = opam exec --switch=$(SWITCH) --
PKG =
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

setup:
	@command -v opam >/dev/null 2>&1 || { echo "Error: opam is required"; exit 1; }
	@opam init --disable-sandboxing --bare -y >/dev/null 2>&1 || true
	@if [ ! -d _opam ]; then opam switch create $(SWITCH) ocaml-base-compiler.$(OCAML_VERSION) -y; fi
	@opam install --switch=$(SWITCH) -y ocamlfind $(OPAM_PACKAGES)

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

$(BUILDDIR)/test_parse.cmo: test/test_parse.ml Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(BUILDDIR)/test_validate.cmo: test/test_validate.ml Makefile | $(BUILDDIR) setup
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -c $< -o $@

$(NAME): $(NATIVE_OBJ)
	$(RUN) ocamlfind ocamlopt $(OCAMLFLAGS) $(PKG) -linkpkg $^ -o $@

$(BYTE): $(BYTE_OBJ)
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -linkpkg $^ -o $@

$(UNIT): $(BUILDDIR)/automaton.cmo  $(BUILDDIR)/parse.cmo  $(BUILDDIR)/validate.cmo $(UNIT_OBJ)
	$(RUN) ocamlfind ocamlc $(OCAMLFLAGS) $(PKG) -linkpkg $^ -o $@

unit ut: $(UNIT)
	@$(RUN) ./$(UNIT)
# 	@echo "No unit tests yet"

e2e:
	@echo "No end-to-end tests yet"

test: unit e2e

clean:
	@rm -rf $(BUILDDIR)

fclean: clean
	@rm -f $(NAME) $(BYTE)

re: fclean all

distclean: fclean
	@rm -rf _opam

.PHONY: all byte setup unit ut e2e test clean fclean re distclean
