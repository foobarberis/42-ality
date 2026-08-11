type state = {
  automaton_state : string;
  reversed_sequence : string list;
}

(* Start at the automaton's initial state. *)
let initial automaton =
  {
    automaton_state = automaton.Automaton.initial;
    reversed_sequence = [];
  }

let reset automaton =
  initial automaton

let sequence state =
  List.rev state.reversed_sequence

(* Follow [token], or reset if there is no matching transition. *)
let advance automaton state token =
  match Automaton.follow automaton state.automaton_state token with
  | Some automaton_state ->
      {
        automaton_state;
        reversed_sequence = token :: state.reversed_sequence;
      }
  | None -> initial automaton

(* After a failed sequence, retry [token] from the start: it may begin the
   next combo. *)
let handle_token automaton state token =
  let next = advance automaton state token in
  if sequence next = [] then
    advance automaton (initial automaton) token
  else
    next
