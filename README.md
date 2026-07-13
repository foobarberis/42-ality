# ft_ality

`ft_ality` is an OCaml finite-state automaton. It reads a grammar of fighting-game moves, trains an automaton, and recognizes moves from terminal input.

## Table of contents

- [Getting started](#getting-started)
  - [Build](#build)
  - [Usage](#usage)
  - [Make targets](#make-targets)
- [Verification](#verification)
- [Grammar](#grammar)
  - [Input mappings](#input-mappings)
  - [Combos](#combos)
  - [Grammar rules](#grammar-rules)
- [Data structures](#data-structures)
  - [Parsed grammar](#parsed-grammar)
  - [Trained automaton](#trained-automaton)
  - [Runtime values](#runtime-values)
- [Control and execution flow](#control-and-execution-flow)

## Getting started

### Build

Build with the system OCaml native compiler:

```sh
make
```

This requires `ocamlopt`.

### Usage

```sh
./ft_ality res/subject.gmr
```

The program requires an interactive POSIX terminal with `stty`. If terminal setup fails, it exits with:

```text
Error: interactive terminal required
```

Press `Ctrl-D` to quit. The program restores the initial terminal mode on normal exit, `Ctrl-C`, and `SIGTERM`.

### Make targets

- `make` or `make all` — build `ft_ality`
- `make test` — build and run unit and executable-level tests
- `make clean` — remove `_build/`
- `make fclean` — run `clean` and remove `ft_ality`
- `make re` — run `fclean` then rebuild

## Verification

Run the automated checks with:

```sh
make test
```

## Grammar

A grammar file contains two sections in this order:

```text
#input
<key>;<token>
...

#combos
<token>,<token>,...;<move name>
...
```

### Input mappings

`#input` maps each physical key identifier to an automaton token:

```text
q;Block
down;Down
s;[BK]
d;[BP]
```

A key identifier can be a printable ASCII character other than whitespace, `;`, `,`, or `#`, or one of these names:

```text
up down left right
space tab enter escape backspace
semicolon comma hash
```

Use `semicolon`, `comma`, and `hash` for delimiter characters, and `space` or `tab` for whitespace. Function keys are not supported.

### Combos

`#combos` maps an ordered token sequence to the move name printed when that sequence is recognized:

```text
[BP],[BK],[BK],Down;Sonya
[BP],[BP],[FP];Freddy Krueger
```

### Grammar rules

- The first non-blank line is `#input`. It appears once and precedes the single `#combos` header.
- Blank lines are ignored.
- Whitespace around keys, tokens, move names, `;`, and `,` is ignored. Whitespace within a token or move name is preserved.
- Keys, tokens, and move names are case-sensitive after trimming.
- Each input entry contains exactly one `;`, a non-empty supported key identifier, and a non-empty token. Keys and tokens cannot contain `;` or `,`.
- Each physical key in `#input` is unique. Several keys may map to the same token.
- A valid grammar contains at least one input mapping and one combo entry.
- Each combo entry contains exactly one `;`, with a non-empty move name. Move names cannot contain `;`.
- The combo sequence is one or more non-empty tokens separated by `,`. Leading, trailing, and repeated commas are invalid.
- Every combo token must be declared in `#input`.
- A token may occur repeatedly in a combo and in any number of combo entries.
- Several combos may use the same token sequence. All corresponding move names are displayed in grammar order.
- Comments and escaping are not supported. A trimmed line beginning with `#` is valid only as a section header.

## Data structures

This example covers key aliases, multiple moves for one sequence, shared prefixes, branching, and repeated tokens:

```text
#input
a;A
e;A
b;B
c;C
d;D

#combos
A;Jab
A;Alternate Jab
A,B;One-Two
A,B,A;Repeat Strike
A,C;Branch Strike
D,A;Counter Jab
```

### Parsed grammar

`Parse.load_automaton` represents the file as a `Parse.grammar` record:

```ocaml
type grammar = {
  key_map : (string * string) list;
  combos : (string list * string) list;
}
```

The example parses to:

```ocaml
{
  key_map = [
    ("a", "A"); ("e", "A"); ("b", "B");
    ("c", "C"); ("d", "D");
  ];
  combos = [
    (["A"], "Jab");
    (["A"], "Alternate Jab");
    (["A"; "B"], "One-Two");
    (["A"; "B"; "A"], "Repeat Strike");
    (["A"; "C"], "Branch Strike");
    (["D"; "A"], "Counter Jab");
  ];
}
```

A physical key and an automaton token are different values. Both `a` and `e` map to token `A`, so they are keyboard aliases for the same automaton input symbol.

### Trained automaton

`Automaton.train` converts the combos into an `Automaton.t` record:

```ocaml
type t = {
  key_map : (string * string) list;
  initial : string;
  finals : (string * string) list;
  transitions : (string * (string * string) list) list;
}
```

The example produces this shared-prefix trie. States are nodes, tokens label edges, and recognition states are marked `final`:

```text
s0
├── A ──> s1 [final: Jab, Alternate Jab]
│          ├── B ──> s2 [final: One-Two]
│          │          └── A ──> s3 [final: Repeat Strike]
│          └── C ──> s4 [final: Branch Strike]
└── D ──> s5
           └── A ──> s6 [final: Counter Jab]
```

The trained record is conceptually:

```ocaml
{
  key_map = [
    ("a", "A"); ("e", "A"); ("b", "B");
    ("c", "C"); ("d", "D");
  ];
  initial = "s0";
  transitions = [
    ("s0", [("A", "s1"); ("D", "s5")]);
    ("s1", [("B", "s2"); ("C", "s4")]);
    ("s2", [("A", "s3")]);
    ("s5", [("A", "s6")]);
  ];
  finals = [
    ("s1", "Jab");
    ("s1", "Alternate Jab");
    ("s2", "One-Two");
    ("s3", "Repeat Strike");
    ("s4", "Branch Strike");
    ("s6", "Counter Jab");
  ];
}
```

Association-list order is an implementation detail and does not affect transition lookup. The fields map to the formal automaton definition:

- `Q` comprises `initial`, all transition sources and targets, and the states in `finals`. State identifiers are generated strings such as `s0` and `s1`.
- `Σ` is the set of combo tokens: `A`, `B`, `C`, and `D`. `key_map` translates physical keys into these tokens.
- `Q0` is `initial`, always `s0`.
- `F` is represented by the states in `finals`.
- `δ` is represented by `transitions`. For example, `("s1", [("B", "s2")])` contains `δ(s1, B) = s2`.

A leaf such as `s3` has no `transitions` entry because it has no outgoing edge. A final state may still have outgoing transitions: `s1` recognizes both `Jab` moves and prefixes three longer combos. `finals` stores `(state, move)` pairs because one state may recognize several moves.

### Runtime values

`Execution.state` stores the current position in the trained automaton, not another copy of the automaton:

```ocaml
type state = {
  automaton_state : string;
  reversed_sequence : string list;
}
```

After tokens `A`, then `B`, it contains:

```ocaml
{
  automaton_state = "s2";
  reversed_sequence = ["B"; "A"];
}
```

The sequence is reversed so a new token can be prepended in constant time. `Execution.sequence` reverses it for display. Keyboard input is represented by the `Runtime.event` variant:

```ocaml
type event =
  | Key of string
  | Unsupported_key
  | Ignored
  | Timeout
  | Quit
```

The parsed grammar, trained automaton, and execution states are immutable values. Runtime progress creates a new `Execution.state`; it does not mutate the trained automaton.

## Control and execution flow

1. **Command line:** `main` in `src/ft_ality.ml` accepts one grammar path or a help option. Any other argument count prints usage and exits with status `1`.
2. **Parsing:** `Parse.load_automaton` in `src/parse.ml` reads the file into a `Parse.grammar`. It checks section order, separators, key identifiers, and empty fields, then closes the input channel on success or failure.
3. **Validation:** `Validate.validate_automaton` in `src/validate.ml` requires non-empty sections, unique physical keys, and combo tokens declared in `key_map`. Parsing or validation errors are reported before mappings or combos are printed.
4. **Training:** after validation, `Training.run_training` in `src/training.ml` prints the grammar and calls `Automaton.create`. `Automaton.train` walks each combo from `s0`, reuses shared transitions, creates an `sN` state for each missing transition, and records the move at the final state.
5. **Terminal setup:** `Keyboard.init` in `src/keyboard.ml` saves the terminal mode, disables echo and canonical buffering, sets a 300 ms read timeout, and installs cleanup handlers for `SIGINT` and `SIGTERM`.
6. **Event decoding:** `Keyboard.read_event` converts characters and escape sequences into `Runtime.event` values. Pressing `a` produces `Key "a"`; `Ctrl-D` produces `Quit`.
7. **Key resolution:** `Runtime.loop` in `src/runtime.ml` uses `Automaton.resolve_key` to map `Key "a"` to token `A`. Unmapped and unsupported keys commit a pending move, then reset recognition.
8. **State transition:** `Execution.handle_token` in `src/execution.ml` follows the transition for the current state and token. If no transition exists, runtime discards the current sequence and retries that token once from `s0`, where it may begin another combo. A pending move is printed before this retry.
9. **Recognition:** a final state without outgoing transitions prints immediately. A final state with outgoing transitions remains pending for 300 ms. A timeout commits a pending move but preserves a non-final partial sequence. All moves attached to the selected state print in grammar order.
10. **Shutdown:** `run` in `src/ft_ality.ml` calls `Keyboard.shutdown` after normal completion or a runtime exception. Signal handlers restore the terminal before exiting on `Ctrl-C` or `SIGTERM`.

With the example grammar, pressing `a` follows `s0 --A--> s1`. Since `s1` is final and has outgoing transitions, runtime waits:

- a timeout prints `Jab` and `Alternate Jab`;
- `b` continues to pending `One-Two` at `s2`;
- another `a` reaches leaf `s3` and prints `Repeat Strike` immediately.

Recognition is non-overlapping: tokens consumed by one move are not reused by the next.
