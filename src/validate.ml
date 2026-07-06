exception Validation_error of string

let ensure condition message =
  if not condition then
    raise (Validation_error message)

let rec has_duplicates xs =
  match xs with
  | [] | [_] -> false
  | x :: rest -> List.mem x rest || has_duplicates rest

let rec input_exists (input: string) (input_map: (string * string) list) =
  match input_map with
  | [] -> false
  | (_, token) :: rest -> token = input || input_exists input rest

let validate_input (input_map: (string * string) list) =
  let inputs = List.map fst input_map in
  ensure (not (has_duplicates inputs)) "Duplicate inputs found in input_map"

let validate_combos_name (combos: (string list * string)list) =
  let combo_names = List.map snd combos in
  ensure (not (has_duplicates combo_names)) "Duplicate combo names found in combos"

let validate_combos_inputs_unique (combos: (string list * string)list) =
  let pattern = List.map fst combos in
   ensure (not (has_duplicates pattern)) "Duplicate input patterns found in combos"

let validate_combos_inputs (combos: (string list * string) list) (input_map: (string * string) list) =
  let rec aux combos =
    match combos with
    | [] -> ()
    | (inputs, _) :: rest ->
      List.iter (fun input ->
        ensure (input_exists input input_map) ("Input '" ^ input ^ "' in combos does not exist in input_map")
      ) inputs;
      aux rest
  in
  aux combos


let validate_automaton (parsed: Automaton.ParsingTypes.parsed_grammar): unit = 
  try
    validate_input parsed.input_map;
    validate_combos_name parsed.combos;
    validate_combos_inputs parsed.combos parsed.input_map;
    validate_combos_inputs_unique parsed.combos;
  with Validation_error message ->
    failwith message