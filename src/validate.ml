exception Validation_error of string

let ensure condition message =
  if not condition then raise (Validation_error message)

let rec has_duplicates values =
  match values with
  | [] | [_] -> false
  | value :: rest -> List.mem value rest || has_duplicates rest

let input_exists token input_map =
  List.exists (fun (_, declared_token) -> declared_token = token) input_map

let validate_input input_map =
  ensure (input_map <> []) "#input must contain at least one mapping";
  let keys = List.map fst input_map in
  let tokens = List.map snd input_map in
  ensure (not (has_duplicates keys)) "duplicate physical key in #input";
  ensure (not (has_duplicates tokens)) "duplicate token in #input"

let validate_combos_name combos =
  let names = List.map snd combos in
  ensure (not (has_duplicates names)) "duplicate move name in #combos"

let validate_combos_inputs combos input_map =
  List.iter
    (fun (tokens, _) ->
      List.iter
        (fun token ->
          ensure (input_exists token input_map)
            ("combo token '" ^ token ^ "' is not declared in #input"))
        tokens)
    combos

let validate_combos combos input_map =
  ensure (combos <> []) "#combos must contain at least one combo";
  validate_combos_name combos;
  validate_combos_inputs combos input_map

let validate_automaton parsed =
  validate_input parsed.Automaton.ParsingTypes.input_map;
  validate_combos parsed.Automaton.ParsingTypes.combos
    parsed.Automaton.ParsingTypes.input_map
