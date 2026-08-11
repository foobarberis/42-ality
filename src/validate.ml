exception Validation_error of string

let ensure condition message =
  if not condition then raise (Validation_error message)

(* Check whether a value appears more than once. *)
let rec has_duplicates values =
  match values with
  | [] | [_] -> false
  | value :: rest -> List.mem value rest || has_duplicates rest

let input_exists token key_map =
  List.exists (fun (_, declared_token) -> declared_token = token) key_map

(* Require at least one input and reject duplicate physical keys. *)
let validate_input key_map =
  ensure (key_map <> []) "#input must contain at least one mapping";
  let keys = List.map fst key_map in
  ensure (not (has_duplicates keys)) "duplicate physical key in #input"

(* Require combos to use tokens declared in #input. *)
let validate_combos combos key_map =
  ensure (combos <> []) "#combos must contain at least one combo";
  List.iter
    (fun (tokens, _) ->
      List.iter
        (fun token ->
          ensure (input_exists token key_map)
            ("combo token '" ^ token ^ "' is not declared in #input"))
        tokens)
    combos

(* Check rules that span multiple grammar entries. *)
let validate_automaton parsed =
  validate_input parsed.Parse.key_map;
  validate_combos parsed.Parse.combos parsed.Parse.key_map
