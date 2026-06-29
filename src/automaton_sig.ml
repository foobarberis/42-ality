(* Automata implementation with the module type wich represente a finite state machine*)

module type automataTypes = sig 
  type state
  type input
  type t
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
  val buildInput : ( input * string) list -> t ->  t
  val buildInitial :  state -> t -> t
  val buildFinals : (state * string) list -> t -> t
  val buildTransitions : (state * (input * state) list) list -> t -> t
  val add_input : input -> string -> t -> t
  val add_transition : state -> input -> state -> t -> t
  val add_final : tate -> string -> t -> t
end 

module type transitions_builder = sig 
  include automata_types
  val count : int ref
  val inc_state : unit -> string
  val trainingAutomata : (input list * string) list -> t -> t
end

module type training = sig 
  include automata_types
  val run_training : string -> t
end