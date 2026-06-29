module AutomataTypes = struct
  type state = string
  type input = string
  type t = {
    name : string;
    input_map : (input * string) list;
    initial : state;
    finals : (state * string) list;
    transitions : (state * (input * state) list) list;
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
  let buildAutomata automata=
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

module TransitionBuilder : Automaton_sig.TransitionBuilder = struct 
  include AutomataTypes (*type combo (input list * string) list*)

  let counter = ref 0

  let inc_state () =
    let s = "s" ^ string_of_int !counter in
    incr counter;
    s

  let trainingAutomata combos automata =
    let rec process automata state inputs =
      match inputs with
      | [] -> (automata, state)
      | inp :: rest ->
        let next_state = inc_state () in 
          let t = AutomataBuilder.add_transition automata state inp next_state
          in process t next_state rest
    in let rec aux automata = function   
      | [] -> automata
      | (inputs, combo_name) :: rest ->
          let start_state = inc_state () in 
          let aut, finale_state = process automata start_state inputs in
          counter := 0;
          let t = AutomataBuilder.add_final aut finale_state combo_name
          in aux t rest
      in aux automata combos
end

module Training : Automaton_sig.training = struct
  includes AutomataTypes

  let run_training path =
    let parse_struct =  load_automaton path in
      Validate.validate_automaton parse_struct;
      AutomataBuilder.buildAutomata "machine"
      |> AutomataBuilder.buildInput parse_struct.input_map
      |> AutomataBuilder.buildInitial "s0"
      |> TransitionBuilder.trainingAutomata parse_struct.combos
end