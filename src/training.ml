module type training = sig 
  include Automaton_sig.automata_types
  val run_training : string -> t
end

module Training : training with type t = Automaton.AutomataTypes.t and type input = Automaton.AutomataTypes.input = struct
  include Automaton.AutomataTypes
  include Automaton.ParsingTypes

  let run_training path =
    let parse_struct =  Parse.load_automaton path in
      (* Validate.validate_automaton parse_struct; *)
      Automaton.AutomataBuilder.buildAutomata "machine"
      |> Automaton.AutomataBuilder.buildInput parse_struct.input_map
      |> Automaton.AutomataBuilder.buildInitial "s0"
      |> Automaton.TransitionBuilder.trainingAutomata parse_struct.combos
end
