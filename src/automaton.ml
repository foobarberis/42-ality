module AutomataTypes = struct
  type input = string
  type t = {
    name : string;
    input_map : (input * string) list;
    initial : string;
    finals : (string * string) list;
    transitions : (string * (input * string) list) list;
    }
end
  
module ParsingTypes = struct 
  type parsed_grammar = {
  input_map : (AutomataTypes.input * string) list;
  combos : (AutomataTypes.input list * string) list;
  }

  let build_parsed_grammar =
    {input_map = []; combos = []}
  
  let build_parsed_inputs _input_map gmr = 
    {gmr with input_map = _input_map}

  let build_parse_combos _combos gmr= 
    {gmr with combos = _combos}
end

module Automata : Automaton_sig.automata with type t = AutomataTypes.t and type input = AutomataTypes.input = struct
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

module AutomataBuilder : Automaton_sig.automataBuilder with type t = AutomataTypes.t and type input = AutomataTypes.input = struct
  include AutomataTypes
  let buildAutomata automata_name =
    {name = automata_name; input_map = []; initial = "s0"; finals = []; transitions = []}

  let buildInput _input_map automata =
    {automata with input_map = _input_map}
  
  let buildInitial init_state automata =
    {automata with initial = init_state}
  
  let buildFinals _finals automata =
    {automata with finals = _finals}
  
  let buildTransitions _transitions automata =
    {automata with transitions = _transitions}
  
  let add_input input move_name automata =
    {automata with input_map = (input, move_name) :: automata.input_map}

  let add_transition from_state input to_state automata =
    match List.assoc_opt from_state automata.transitions with
      | Some transitions ->
        let new_transitions = (input, to_state) :: transitions in
          {automata with transitions = (from_state, new_transitions) :: List.remove_assoc from_state automata.transitions}
      | None ->
        {automata with transitions = (from_state, [ (input, to_state) ]) :: automata.transitions}

  let add_final state combo_name automata =
    {automata with finals = (state, combo_name) :: automata.finals}
end

module TransitionBuilder : Automaton_sig.transitions_builder with type t = AutomataTypes.t and type input = AutomataTypes.input 
= struct 
  include AutomataBuilder

  let counter = ref 1

  let inc_state () =
    let s = "s" ^ string_of_int !counter in
    incr counter;
    s

  let trainingAutomata combos automata =
    let rec process automata state inputs =
      match inputs with
      | [] -> (automata, state)
      | inp :: rest ->
        match Automata.find_transition automata state inp with 
          | Some existing_state ->
            process automata existing_state rest
          | None -> 
             let next_state = inc_state () in 
             let t = AutomataBuilder.add_transition state inp next_state automata
             in process t next_state rest
    in let rec aux automata = function   
      | [] -> automata
      | (inputs, combo_name) :: rest ->
          let start_state = "s0" in 
          let aut, finale_state = process automata start_state inputs  in
          let t = AutomataBuilder.add_final finale_state combo_name aut
          in aux t rest
      in aux automata combos
    
    let sort_automata automata = 
      let sorted_transitions = List.sort (fun (s1, _) (s2, _) -> String.compare s1 s2) automata.AutomataTypes.transitions in
      let sorted_finals = List.sort (fun (s1, _) (s2, _) -> String.compare s1 s2) automata.AutomataTypes  .finals in
      AutomataBuilder.buildTransitions sorted_transitions (AutomataBuilder.buildFinals sorted_finals automata)
end
