module type training = sig
  include Automaton_sig.automata_types
  val run_training : ?output:out_channel -> string -> t
end

module Training : training with type t = Automaton.AutomataTypes.t and type input = Automaton.AutomataTypes.input = struct
  include Automaton.AutomataTypes
  include Automaton.ParsingTypes

  let run_training ?(output = stdout) path =
    let parsed = Parse.load_automaton path in
    Validate.validate_automaton parsed;
    Parse.print_grammar ~channel:output parsed;
    Automaton.AutomataBuilder.buildAutomata "machine"
    |> Automaton.AutomataBuilder.buildInput parsed.input_map
    |> Automaton.AutomataBuilder.buildInitial "s0"
    |> Automaton.TransitionBuilder.trainingAutomata parsed.combos
    |> Automaton.TransitionBuilder.sort_automata
end
