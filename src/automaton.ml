module AutomataTypes = struct
  type state = string
  type input = char
  type t = {
    name : string;
    input_map : (input * string) list;
    initial : state;
    finals : (state * string) list;
    transitions : (state * (input * state) list) list; 
  }
end

module Automata : Automaton_sig.automata = struct
  include AutomataTypes
  let find_transition automata state input =
    match List.assoc_opt state automata.transitions with
      | Some transitions -> List.assoc_opt input transitions
      | None -> None

  let step automata state input = 
    find_transition automata state input
    (* TODO complete step implementation here *)

  let is_final automata state =
    List.mem_assoc state automata.finals
    
  let get_final_combo automata state =
    List.assoc_opt state automata.finals

  let get_move automata input = 
    List.assoc_opt input automata.input_map
end

module AutomataBuilder : Automaton_sig.automataBuilder = struct
  include AutomataTypes
  let buildAutomata automata_name =
    {name = automata_name; input_map = []; initial = "s0"; finals = []; transitions = []}

  let buildInput  automata _input_map =
    {automata with input_map = _input_map}
  
  let buildInitial automata init_state =
    {automata with initial = init_state}
  
  let buildFinals automata _finals =
    {automata with finals = _finals}
  
  let buildTransitions automata  _transitions =
    {automata with transitions = _transitions}
  
  let add_input automata input move_name =
    {automata with input_map = (input, move_name) :: automata.input_map}

  let add_transition automata from_state input to_state =
    match List.assoc_opt from_state automata.transitions with
      | Some transitions ->
        let new_transitions = (input, to_state) :: transitions in
          {automata with transitions = (from_state, new_transitions) :: List.remove_assoc from_state automata.transitions}
      | None ->
        {automata with transitions = (from_state, [ (input, to_state) ]) :: automata.transitions}

  let add_final automata state combo_name =
    {automata with finals = (state, combo_name) :: automata.finals}
end
