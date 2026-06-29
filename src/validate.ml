exception Validation_error of string

let ensure condition message =
  if not condition then
    raise (Validation_error message)

let rec has_duplicates xs =
  match xs with
  | [] | [_] -> false
  | x :: rest -> is_in x rest || has_duplicates rest

let validate_input (input_map: (string * string) List) =

let validate_combos (combos: (string List * string)List) =

let validate_automaton (parsed: Automaton.ParsingTypes.parsed_grammar): unit = 
  validate_input parsed.input_map
  validate_combos parsed.combos