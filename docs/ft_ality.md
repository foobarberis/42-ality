# ft_ality

## Subject: General instructions

- The inputs and outputs presented in this subject are only given as guidelines. You are free to format those as you wish. As such, you may index your automaton’s states whichever way you see fit. If you have a doubt, just play it safe and do it like in the subject.

- This project is to do in functionnal. Any functionnal language is okay, as long as the whole project is done using functionnal logic. This will be verified during evaluation.

- Any library that does the job for you is forbidden. As usual.

- The `open` keyword is forbidden and considered cheating.

- Your code will be compiled, which means you should never have the `;;` token in your source files.

- You are allowed to use the following modules:
  - `Pervasives`
  - `List`
  - `String`
  - `Sys`
  - `Sdl`
  - `Sdlevent`
  - `Sdlkey`

- If you want to use a module and it’s not in this list, you can’t.

- No coding style is enforced for this project; but remember that small functions and wisely designed modules are elements to writing well thought code. Your graders will have the possibility to give you bonus points if your code is elegant and robust.

- You must provide a Makefile which will build your entire project.

## Subject: Mandatory part

The runtime of this project mainly consists of two steps: training the automaton and running it.

### Formal definition

A finite-state automaton `A` is a tuple containing the following elements:

```text
A = <Q, Σ, Q0, F, δ>
```

- `Σ` is the automaton’s input alphabet.
- `Q` is the set of states in the automaton.
- `Q0` is the starting state, with `Q0 ∈ Q`.
- `F` is the set of recognition states, with `F ⊆ Q`.
- `δ` is a function that assigns transitions to the automaton’s states; a transition is a state associated with a pair consisting of a state and a symbol from the alphabet, making the function’s type `Q × Σ → Q`.

The main idea is that an automaton reads the input, symbol by symbol, and goes from one state to another at each symbol using the transition function `δ`. At the end of the input, if the automaton is in a recognition state, it recognizes the word. If it is not in a recognition state, it does not recognize the word.

Note: the transition function could be a set.

### Automaton training

Your automaton will be built at runtime, using grammar files that contain the moves to be learned by the automaton.

The file path of one grammar will be given in the command line arguments.

Since moves are usually very simple, all you have to do is split/tokenize your rule to get a list of tokens, and then give it to the automaton, which will generate transitions for each token in succession.

This operation should be very quick, near-instant.

### Automaton running and language recognition

Once you have trained your automaton, run it.

Your program will wait for input from the keyboard, like the training mode of a fighting game. The user must be able to press keys on their keyboard, using a key mapping displayed on the screen, and move names should be displayed when their key combinations are executed.

The key mappings must be automatically computed from the grammar. If they are hardcoded, the project does not satisfy the requirement.

Example:

```text
% ./ft_ality grammars/mk9.gmr
Key mappings:
q -> Block
down -> Down
w -> Flip Stance
left -> Left
right -> Right
e -> Tag
a -> Throw
up -> Up
s -> [BK]
d -> [BP]
z -> [FK]
x -> [FP]
----------------------

[BP]
Claw Slam (Freddy Krueger) !!
Knockdown (Sonya) !!
Fist of Death (Liu-Kang) !!

[BP], [FP]
Saibot Blast (Noob Saibot) !!
Active Duty (Jax) !!
```

## Evaluation: Mandatory part

This section covers the most elementary and fundamental features demanded by the subject. It has to be completed perfectly to unlock bonuses.

### Automaton

There must be an automaton implemented somewhere in the code. It could be a class, a module, or it could be in one file containing the entire project.

The automaton has to at least loosely correspond to the formal definition given in the subject. In other words, you should be able to find:

- states;
- recognition states;
- transitions.

The student must have implemented the automaton themselves. If they have not, for example if a magical automaton library was imported or the student cannot explain the code, the grade is `-42`.

### Basic program behaviour

Run the program with any grammar.

The program should:

- display the keyboard mapping;
- wait for the user to press keys;
- detect that the user is pressing keys;
- print what the user is inputting;
- display move names from time to time when recognized.

### Small grammars

Make a small grammar file with only three or four moves, and run the program with it.

You should be able to execute every move from the file.

This question is also the opportunity to check if the keyboard mapping is computed from the grammar file. It has to be computed from the grammar file. If it is not, the question is failed.

### Homonymous rules

Make another small grammar with several rules, but all the rules must be executed through the same key combinations.

Run the program and execute the key combinations. You must be able to see every rule name in the grammar.

### Common prefixes

Make another small grammar with several rules, but all the rules must have the same prefix.

Example:

```text
Move A;a
Move B;a,b
Move C;a,b,a
```

The program should be able to display move names as they appear, and the user must be able to execute every move in the grammar.

### Error handling

Functional programming is also about rigor, so simple erratic behaviours are tested.

During this section and the rest of the defense, any uncaught exception, infinite loop, freeze, or erratic behaviour means the defense ends with a `Crash` status, and the grade is `0`.

#### Command line arguments

Try running the program with:

- no arguments;
- more than one argument;
- a file that does not exist;
- a file the program is not allowed to read, for example `/etc/master.passwd`.

The program must exit gracefully.

#### Input

Mash the keyboard gently.

Try to:

- press keys outside the keyboard mapping;
- execute keys that do not constitute a particular move in the grammar.

The program must reset the input buffer when appropriate and keep running whatever happens.
