(* Automata implementation with the module type wich represente a finite state machine*)

module type automata_types = sig 
  type state
  type input
  type t
  (* type t = {
    name : string;
    input_map : (input * string) list;
    initial : state;
    finals : (state * string) list;
    transitions : (state * (input * state) list) list;
  } *)
end

module type automata = sig
  (* for help execution *)
  include automata_types
  val step : t -> state -> input -> state option
  val find_transition : t -> state -> input -> state option
  val is_final : t -> state -> bool
  val get_final_combo : t -> state -> string option
  val get_move : t -> input -> string option
end

module type automataBuilder = sig
  include automata_types
  val buildAutomata : string -> t
  val buildInput : t -> ( input * string) list ->  t
  val buildInitial :  t -> state -> t
  val buildFinals : t -> (state * string) list -> t
  val buildTransitions : t -> (state * (input * state) list) list -> t
  val add_input : t -> input -> string -> t
  val add_transition : t -> state -> state -> t
  val add_final : t -> state -> string -> t
  val mark_final : t -> state -> string -> t
end 

(* module type transitionsBuilder = sig 
end *)