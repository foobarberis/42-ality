module type automata_types = sig 
  type input
  type t
end

module type automata = sig
  (* for help execution *)
  include automata_types
  val step : t -> string -> input -> string option
  val find_transition : t -> string -> input -> string option
  val is_final : t -> string -> bool
  val get_final_combo : t -> string -> string option
  val get_move : t -> input -> string option
end

module type automataBuilder = sig
  include automata_types
  val buildAutomata : string -> t
  val buildInput : ( input * string) list -> t ->  t
  val buildInitial :  string -> t -> t
  val buildFinals : (string * string) list -> t -> t
  val buildTransitions : (string * (input * string) list) list -> t -> t
  val add_input : input -> string -> t -> t
  val add_transition : string -> input -> string -> t -> t
  val add_final : string -> string -> t -> t
end 

module type transitions_builder = sig 
  include automataBuilder
  type transition_builder
  val inc_state : int -> string * int
  val trainingAutomata : (input list * string) list -> t -> t
  val compare_state : string -> string -> int
  val sort_automata : t -> t
end
