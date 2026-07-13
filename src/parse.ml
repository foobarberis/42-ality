exception Parse_error of string

type grammar = {
  key_map : (string * string) list;
  combos : (string list * string) list;
}

type section =
  | Expect_input
  | Inputs
  | Combos

let line_error line reason =
  "line " ^ string_of_int line ^ ": " ^ reason

let syntax_error line reason =
  raise (Parse_error (line_error line reason))

let grammar_file_error path =
  Parse_error ("cannot read grammar file: " ^ path)

let load_grammar path =
  try open_in path with
  | Sys_error _ -> raise (grammar_file_error path)

let close_grammar path channel =
  try close_in channel with
  | Sys_error _ -> raise (grammar_file_error path)

let has_prefix_hash value =
  String.length value > 0 && value.[0] = '#'

let named_keys =
  [ "up"; "down"; "left"; "right";
    "space"; "tab"; "enter"; "escape"; "backspace";
    "semicolon"; "comma"; "hash" ]

(* A direct key is one printable character, excluding grammar delimiters. *)
let is_direct_key key =
  if String.length key <> 1 then
    false
  else
    let character = key.[0] in
    let code = int_of_char character in
    code >= 33 && code <= 126
    && character <> ';'
    && character <> ','
    && character <> '#'

(* Support direct keys and the named aliases above. *)
let is_supported_key key =
  is_direct_key key || List.mem key named_keys

(* Split an entry at its single semicolon and trim both sides. *)
let split_entry line_number kind line =
  match String.split_on_char ';' line with
  | [left; right] -> String.trim left, String.trim right
  | _ ->
      syntax_error line_number
        (kind ^ " entry must contain exactly one ';' separator")

(* Parse one #input mapping and check its syntax. *)
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

(* Parse a #combos entry into its tokens and move name. *)
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

(* Report which required section is missing at end of file. *)
let eof_error line section =
  match section with
  | Expect_input -> syntax_error line "expected #input before end of file"
  | Inputs -> syntax_error line "expected #combos before end of file"
  | Combos -> assert false

(* Parse in one pass, keeping source line numbers for errors and preserving
   declaration order. *)
let parse_automaton path channel =
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
              {
                key_map = List.rev inputs;
                combos = List.rev combos;
              }
        end
    | exception Sys_error _ ->
        raise (grammar_file_error path)
  in
  read_lines 1 Expect_input [] []

(* Load a grammar and close its file even if parsing fails. *)
let load_automaton path =
  let channel = load_grammar path in
  match parse_automaton path channel with
  | grammar ->
      close_grammar path channel;
      grammar
  | exception error ->
      close_in_noerr channel;
      raise error

(* Format the mappings and combos shown before training. *)
let string_of_grammar grammar =
  let inputs =
    grammar.key_map
    |> List.map (fun (key, token) -> key ^ " -> " ^ token)
    |> String.concat "\n"
  in
  let combos =
    grammar.combos
    |> List.map (fun (tokens, name) ->
           String.concat ", " tokens ^ " -> " ^ name)
    |> String.concat "\n"
  in
  "Possible inputs:\n" ^ inputs
  ^ "\n\nPossible combos:\n" ^ combos
  ^ "\n----------------------\n"

(* Print the grammar to [channel], or stdout by default. *)
let print_grammar ?(channel = stdout) grammar =
  output_string channel (string_of_grammar grammar)
