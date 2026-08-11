(* Load, validate, and display a grammar before training it. *)
let run_training ?(output = stdout) path =
  let parsed = Parse.load_automaton path in
  Validate.validate_automaton parsed;
  Parse.print_grammar ~channel:output parsed;
  Automaton.create parsed.Parse.key_map parsed.Parse.combos
