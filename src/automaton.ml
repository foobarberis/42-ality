type t = {
  key_map : (string * string) list;
  initial : string;
  finals : (string * string) list;
  transitions : (string * (string * string) list) list;
}

(* Look up the transition for [token] from [state]. *)
let find_transition transitions state token =
  match List.assoc_opt state transitions with
  | Some outgoing -> List.assoc_opt token outgoing
  | None -> None

let follow automaton state token =
  find_transition automaton.transitions state token

(* List the moves for [state] in declaration order. *)
let recognized automaton state =
  let rec collect moves = function
    | [] -> List.rev moves
    | (final_state, move) :: rest ->
        if final_state = state then
          collect (move :: moves) rest
        else
          collect moves rest
  in
  collect [] automaton.finals

let resolve_key automaton key =
  List.assoc_opt key automaton.key_map

let has_outgoing automaton state =
  match List.assoc_opt state automaton.transitions with
  | Some outgoing -> outgoing <> []
  | None -> false

(* Add a [token] transition from [source] to [target]. *)
let rec add_transition source token target = function
  | [] -> [(source, [(token, target)])]
  | (state, outgoing) :: rest ->
      if state = source then
        (state, (token, target) :: outgoing) :: rest
      else
        (state, outgoing) :: add_transition source token target rest

(* Build a trie so combos with the same prefix share states. *)
let train key_map combos =
  let initial = "s0" in
  (* Reuse existing transitions and number each new state from [counter]. *)
  let rec add_tokens transitions counter state = function
    | [] -> transitions, counter, state
    | token :: rest ->
        begin
          match find_transition transitions state token with
          | Some target ->
              add_tokens transitions counter target rest
          | None ->
              let target = "s" ^ string_of_int counter in
              let updated =
                add_transition state token target transitions
              in
              add_tokens ((target, []) :: updated) (counter + 1)
                target rest
        end
  in
  (* Add each combo and mark the state where it ends. *)
  let rec add_combos transitions finals counter = function
    | [] ->
        {
          key_map;
          initial;
          transitions =
            List.rev transitions
            |> List.filter (fun (_, outgoing) -> outgoing <> []);
          finals = List.rev finals;
        }
    | (tokens, move) :: rest ->
        let updated, next_counter, final_state =
          add_tokens transitions counter initial tokens
        in
        add_combos updated ((final_state, move) :: finals)
          next_counter rest
  in
  add_combos [initial, []] [] 1 combos

(* Train an automaton from validated mappings and combos. *)
let create key_map combos =
  train key_map combos
