exception Validation_error of string

let ensure condition message =
  if not condition then
    raise (Validation_error message)

let rec has_duplicates xs =
  match xs with
  | [] | [_] -> false
  | x :: rest -> List.mem x rest || has_duplicates rest

let validate_input (input_map: (string * string) list) =
  let inputs = List.map fst input_map in
  ensure (not (has_duplicates inputs)) "Duplicate inputs found in input_map"

let validate_combos (combos: (string list * string)list) =
  let combo_names = List.map snd combos in
  ensure (not (has_duplicates combo_names)) "Duplicate combo names found in combos"

let validate_automaton (parsed: Automaton.ParsingTypes.parsed_grammar): unit = 
  try
    validate_input parsed.input_map;
    validate_combos parsed.combos;
  with Validation_error message ->
    failwith message