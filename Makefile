.DEFAULT_GOAL := all

NAME = ft_ality
BUILDDIR = _build
UNIT = $(BUILDDIR)/test_unit
MODULES = automaton parse validate training execution runtime keyboard ft_ality
TEST_MODULES = test_support test_parse test_validate test_training test_execution test_runtime test_keyboard
SRC = $(addprefix src/,$(addsuffix .ml,$(MODULES)))
TEST_SRC = $(addprefix test/,$(addsuffix .ml,$(TEST_MODULES)))
OBJ = $(addprefix $(BUILDDIR)/,$(addsuffix .cmx,$(MODULES)))
UNIT_OBJ = $(filter-out $(BUILDDIR)/ft_ality.cmx,$(OBJ)) \
	$(addprefix $(BUILDDIR)/,$(addsuffix .cmx,$(TEST_MODULES)))

OCAMLOPT = ocamlopt
# Enable all warnings except 40, 42, and 70; find compiled module interfaces in _build.
FLAGS = -I $(BUILDDIR)

all: $(NAME)

$(BUILDDIR):
	@mkdir -p $@

$(NAME): $(SRC) Makefile | $(BUILDDIR)
	@set -e; \
	for file in $(SRC); do \
		name=$${file##*/}; \
		$(OCAMLOPT) $(FLAGS) -c $$file -o $(BUILDDIR)/$${name%.ml}.cmx; \
	done
	$(OCAMLOPT) $(FLAGS) $(OBJ) -o $@

$(UNIT): $(NAME) $(TEST_SRC) Makefile
	@set -e; \
	for file in $(TEST_SRC); do \
		name=$${file##*/}; \
		$(OCAMLOPT) $(FLAGS) -c $$file -o $(BUILDDIR)/$${name%.ml}.cmx; \
	done
	$(OCAMLOPT) $(FLAGS) $(UNIT_OBJ) -o $@

test: $(NAME) $(UNIT)
	@./$(UNIT)
	@sh test/test_e2e.sh ./$(NAME)

clean:
	@rm -rf $(BUILDDIR)

fclean: clean
	@rm -f $(NAME)

re: fclean
	@$(MAKE) all

.PHONY: all test clean fclean re
