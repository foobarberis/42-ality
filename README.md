# ft_ality

`ft_ality` is a finite-state automaton project written in OCaml. It reads a grammar file describing fighting-game moves, trains an automaton from those rules, then recognizes moves from keyboard input.

## Table of contents

- [Getting started](#getting-started)
  - [Build](#build)
  - [Usage](#usage)
  - [Make targets](#make-targets)
- [Project overview](#project-overview)
- [Concepts](#concepts)
  - [Grammar](#grammar)
  - [Automaton](#automaton)
  - [Execution](#execution)
- [Implementation notes](#implementation-notes)

## Getting started

### Build

```sh
mise install
make
```

The build downloads pinned SDL2 and SDL12-compat sources, installs them into
`.local/sdl`, then installs the OCaml binding through opam. SDL12-compat
provides the SDL 1.2 API and `sdl-config` needed by `ocamlsdl`; no global SDL
installation is needed. The local switch uses OCaml 4.14.2 because `ocamlsdl`
exposes the required `Sdl`, `Sdlevent`, and `Sdlkey` modules but supports OCaml
versions before 5.

### Usage

```sh
./ft_ality res/subject.gmr
```

The program trains an automaton from the grammar, displays the key mapping, and recognizes configured moves from keyboard input.

### Make targets

- `make` or `make all` — install required dependencies if needed, then build `ft_ality`
- `make byte` — build `ft_ality.byte`
- `make unit` or `make ut` — run unit tests
- `make e2e` — run end-to-end tests
- `make test` — run `unit` and `e2e`
- `make setup` — create the local `opam` switch and install required dependencies
- `make clean` — remove `_build/`
- `make fclean` — run `clean` and remove binaries
- `make re` — run `fclean` then rebuild
- `make distclean` — run `fclean` and remove local SDL sources, libraries, and the `_opam/` switch

## Project overview

The program runs in two phases:

1. **Training**
   - read the grammar file;
   - parse move names and input sequences;
   - build a finite-state automaton from those sequences.

2. **Execution**
   - read the keyboard mapping declared by the grammar;
   - wait for key presses;
   - move through the automaton one token at a time;
   - display recognized move names when a final state is reached.

## Concepts

### Grammar

A grammar file has two sections, in this order:

```text
#input
<key>;<token>
...

#combos
<token>,<token>,...;<move name>
...
```

`#input` declares the keyboard mapping. Each entry maps one physical-key
identifier to one automaton token:

```text
q;Block
down;Down
s;[BK]
d;[BP]
```

A key identifier is either one printable character other than whitespace, `;`,
`,`, and `#`, or a named key. Named keys are lowercase and use these canonical
names:

```text
up down left right
space tab enter escape backspace
semicolon comma hash
f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12
```

Use `semicolon`, `comma`, and `hash` instead of the literal characters because
`;` is the field separator, `,` separates combo tokens, and a trimmed line
beginning with `#` is reserved for section headers. Whitespace cannot be a
literal key identifier; use `space` or `tab`. Hardware-specific keys such as
`fn` are not supported.

`#combos` declares the moves learned by the automaton. The left side is the
ordered token sequence; the right side is the move name shown when that
sequence is recognized:

```text
[BP],[BK],[BK],Up;Sonya
[BP],[BP],[FP];Freddy Krueger
```

The complete format is therefore:

```text
#input
q;Block
down;Down
w;Flip Stance
left;Left
right;Right
e;Tag
a;Throw
up;Up
s;[BK]
d;[BP]
z;[FK]
x;[FP]

#combos
[BP],[BP],[FP];Freddy Krueger
[BP],[BK],[BK],Up;Sonya
```

#### Grammar rules

- The first non-blank line is `#input`. `#input` appears once and precedes
  the single `#combos` header.
- Blank lines are ignored.
- Whitespace around keys, tokens, move names, `;`, and `,` is ignored.
  Whitespace within a token or move name is preserved.
- Keys, tokens, and move names are compared case-sensitively after trimming.
- Section headers must be exactly `#input` and `#combos` after trimming
  surrounding whitespace.
- Each input entry contains exactly one `;`, with a non-empty supported key
  identifier on the left and a non-empty token on the right. Keys and tokens
  cannot contain `;` or `,`.
- Each key and token in `#input` is unique.
- A valid grammar contains at least one input mapping.
- Each combo entry contains exactly one `;`, with a non-empty move name on the
  right. Move names cannot contain `;` and are unique across `#combos`.
- The left side of a combo is one or more non-empty tokens separated by `,`.
  Leading, trailing, and repeated commas are invalid.
- Every combo token must be declared in `#input`. A token may occur more than
  once in one combo and in any number of combo entries.
- A valid grammar contains at least one combo entry.
- Input and combo entries retain their file order, which is also their display
  order.
- Several combo entries may use the same token sequence. They represent
  homonymous moves and every distinct associated move name must be displayed.
  An identical combo entry is invalid.
- Comments and escaping are not supported. A trimmed line beginning with `#`
  is valid only when it is a section header; `#` elsewhere has no special
  meaning.

An empty section is structurally valid, but the grammar fails validation when
`#input` has no mapping or `#combos` has no combo entry.

The program derives its displayed key mapping from `#input`; mappings must not
be hardcoded in the executable.

### Automaton

The automaton represents valid input sequences. It contains:

- states;
- a start state;
- transitions between states;
- final states associated with recognized move names.

Common prefixes should share states. For example, `a`, `a,b`, and `a,b,a` all start from the same `a` transition.

### Execution

The execution layer keeps track of:

- the current automaton state;
- the input sequence typed so far;
- the mapping between physical keys and grammar tokens.

On each mapped key press, the program uses that key's declared token to try to
follow a transition. If the new state is final, its associated move names are
displayed.

#### Input reset semantics

Recognition is non-overlapping: keys used by a recognized move are not reused
by another move.

When the token mapped from a key press cannot continue the current sequence,
the program discards that sequence and tries that same token once from the
start state. If it cannot start a move, the current sequence is empty.

A recognized final state remains active when it has outgoing transitions. This
allows a longer move sharing its prefix to be recognized.

## Implementation notes

The subject restrictions apply to both application code in `src/` and test
code in `test/`. Both depend only on project modules and the subject's module
allowlist: `Pervasives`, `List`, `String`, `Sys`, `Sdl`, `Sdlevent`, and
`Sdlkey`. Neither uses the forbidden `open` keyword or `;;` token. The `;;`
text in a malformed grammar test is string data, not an OCaml token.

## Source layout

- `src/parse.ml` — grammar parsing
- `src/validate.ml` — grammar validation
- `src/automaton.ml` — automaton representation and training
- `src/training.ml` — training orchestration
- `src/execution.ml` — pure input-sequence recognition state
- `src/ft_ality.ml` — CLI entry point
- `res/subject.gmr` — grammar matching the subject example
- `res/common_prefix.gmr` — common-prefix grammar with three final states
- `res/overlapping_sequences.gmr` — overlapping sequences for input-reset checks
- `res/ten_word_sentence.gmr` — larger grammar example
