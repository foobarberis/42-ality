exception Parse_error of string

type section =
  | Expect_input
  | Inputs
  | Combos

let syntax_error line reason =
  raise (Parse_error (Printf.sprintf "line %d: %s" line reason))

let load_grammar path =
  try open_in path with
  | Sys_error message ->
      raise (Parse_error ("failed to open grammar file: " ^ message))

let close_grammar channel =
  try close_in channel with
  | Sys_error message ->
      raise (Parse_error ("failed to close grammar file: " ^ message))

let has_prefix_hash value =
  String.length value > 0 && value.[0] = '#'

let named_keys =
  [ "up"; "down"; "left"; "right";
    "space"; "tab"; "enter"; "escape"; "backspace";
    "semicolon"; "comma"; "hash";
    "f1"; "f2"; "f3"; "f4"; "f5"; "f6";
    "f7"; "f8"; "f9"; "f10"; "f11"; "f12" ]

let is_direct_key key =
  if String.length key <> 1 then
    false
  else
    let character = key.[0] in
    let code = Char.code character in
    code >= 33 && code <= 126
    && character <> ';'
    && character <> ','
    && character <> '#'

let is_supported_key key =
  is_direct_key key || List.mem key named_keys

let split_entry line_number kind line =
  match String.split_on_char ';' line with
  | [left; right] -> String.trim left, String.trim right
  | _ ->
      syntax_error line_number
        (kind ^ " entry must contain exactly one ';' separator")

let parse_input_entry line_number line =
  let key, token = split_entry line_number "input" line in
  if key = "" then
    syntax_error line_number "input key is empty";
  if token = "" then
    syntax_error line_number "input token is empty";
  if not (is_supported_key key) then
    syntax_error line_number ("unsupported input key: " ^ key);
  if String.contains token ',' then
    syntax_error line_number "input token cannot contain ','";
  key, token

let parse_combo_entry line_number line =
  let sequence, name = split_entry line_number "combo" line in
  if sequence = "" then
    syntax_error line_number "combo sequence is empty";
  if name = "" then
    syntax_error line_number "combo name is empty";
  let tokens = List.map String.trim (String.split_on_char ',' sequence) in
  if List.exists (fun token -> token = "") tokens then
    syntax_error line_number "combo contains an empty token";
  tokens, name

let eof_error line section =
  match section with
  | Expect_input -> syntax_error line "expected #input before end of file"
  | Inputs -> syntax_error line "expected #combos before end of file"
  | Combos -> assert false

let parse_automaton channel =
  let rec read_lines line_number section inputs combos =
    match input_line channel with
    | line ->
        let value = String.trim line in
        if value = "" then
          read_lines (line_number + 1) section inputs combos
        else
          begin
            match section with
            | Expect_input ->
                if value = "#input" then
                  read_lines (line_number + 1) Inputs inputs combos
                else if value = "#combos" then
                  syntax_error line_number "expected #input before #combos"
                else if has_prefix_hash value then
                  syntax_error line_number
                    ("unknown section header: " ^ value)
                else
                  syntax_error line_number
                    "expected #input as the first non-blank line"
            | Inputs ->
                if value = "#combos" then
                  read_lines (line_number + 1) Combos inputs combos
                else if value = "#input" then
                  syntax_error line_number "#input appears more than once"
                else if has_prefix_hash value then
                  syntax_error line_number
                    ("unknown section header: " ^ value)
                else
                  let entry = parse_input_entry line_number line in
                  read_lines (line_number + 1) Inputs (entry :: inputs) combos
            | Combos ->
                if value = "#input" then
                  syntax_error line_number
                    "#input appears after #combos"
                else if value = "#combos" then
                  syntax_error line_number "#combos appears more than once"
                else if has_prefix_hash value then
                  syntax_error line_number
                    ("unknown section header: " ^ value)
                else
                  let entry = parse_combo_entry line_number line in
                  read_lines (line_number + 1) Combos inputs (entry :: combos)
          end
    | exception End_of_file ->
        begin
          match section with
          | Expect_input | Inputs -> eof_error line_number section
          | Combos ->
              Automaton.ParsingTypes.build_parsed_grammar
              |> Automaton.ParsingTypes.build_parsed_inputs (List.rev inputs)
              |> Automaton.ParsingTypes.build_parse_combos (List.rev combos)
        end
    | exception Sys_error message ->
        raise
          (Parse_error
             (Printf.sprintf "line %d: failed to read grammar file: %s"
                line_number message))
  in
  read_lines 1 Expect_input [] []

let load_automaton path =
  let channel = load_grammar path in
  match parse_automaton channel with
  | grammar ->
      close_grammar channel;
      grammar
  | exception error ->
      close_in_noerr channel;
      raise error

let string_of_grammar grammar =
  let inputs =
    grammar.Automaton.ParsingTypes.input_map
    |> List.map (fun (key, token) -> key ^ " -> " ^ token)
    |> String.concat "\n"
  in
  let combos =
    grammar.Automaton.ParsingTypes.combos
    |> List.map (fun (tokens, name) ->
           String.concat ", " tokens ^ " -> " ^ name)
    |> String.concat "\n"
  in
  "Possible inputs:\n" ^ inputs
  ^ "\n\nPossible combos:\n" ^ combos
  ^ "\n----------------------\n"

let print_grammar ?(channel = stdout) grammar =
  output_string channel (string_of_grammar grammar)
