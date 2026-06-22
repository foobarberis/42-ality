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
make
```

### Usage

```sh
./ft_ality path/to/grammar.gmr
```

Current base behavior only validates the command line and checks that the grammar file exists. Parsing, automaton training, and keyboard execution will be connected as the project grows.

### Make targets

- `make` or `make all` — install required dependencies if needed, then build `ft_ality`
- `make byte` — build `ft_ality.byte`
- `make unit` or `make ut` — placeholder for future unit tests
- `make e2e` — placeholder for future end-to-end tests
- `make test` — run `unit` and `e2e`
- `make setup` — create the local `opam` switch and install required dependencies
- `make clean` — remove `_build/`
- `make fclean` — run `clean` and remove binaries
- `make re` — run `fclean` then rebuild
- `make distclean` — run `fclean` and remove the local `_opam/` switch

## Project overview

The program will eventually run in two phases:

1. **Training**
   - read the grammar file;
   - parse move names and input sequences;
   - build a finite-state automaton from those sequences.

2. **Execution**
   - compute a keyboard mapping from the grammar tokens;
   - wait for key presses;
   - move through the automaton one token at a time;
   - display recognized move names when a final state is reached.

## Concepts

### Grammar

A grammar file describes moves as names associated with token sequences.

Each non-empty line is one rule:

```text
<move name>;<token1>,<token2>,<token3>
```

Examples:

```text
Move A;a
Move B;a,b
Move C;a,b,a
Claw Slam (Freddy Krueger);[BP]
Saibot Blast (Noob Saibot);[BP],[FP]
```

The parser should read this as:

```text
Move A -> a
Move B -> a, b
Move C -> a, b, a
Claw Slam (Freddy Krueger) -> [BP]
Saibot Blast (Noob Saibot) -> [BP], [FP]
```

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

On each key press, the program tries to follow a transition. If the new state is final, the associated move name is displayed.

## Implementation notes

Current source layout:

- `src/ft_ality.ml` — CLI entry point
- `res/sample.gmr` — small grammar fixture for smoke checks

Planned source layout:

- `src/grammar.ml` — grammar parsing
- `src/automaton.ml` — automaton representation and training
- `src/keymap.ml` — keyboard mapping
- `src/execute.ml` — runtime input loop

This layout may change as implementation details become clearer.
