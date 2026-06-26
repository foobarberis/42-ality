exception Parse_error of string

let load_grammar (path: string): in_channel =
  try open_in path with
    | Sys_error msg -> raise (Parse_error ("Failed to open file: " ^ msg))

let close_file (in_channel: in_channel): unit =
  try close_in in_channel with
    | Sys_error msg -> raise (Parse_error ("Failed to close file: " ^ msg))

let get_next_line (in_channel: in_channel): string option =
  try Some (input_line in_channel) with
    | End_of_file -> None
    | Sys_error msg -> raise (Parse_error ("Failed to read line: " ^ msg))

let field (in_channel: in_channel): string list =
  try let rec aux acc = 
    match get_next_line in_channel with
      | Some line when String.trim line = "" -> aux acc
      | Some line when String.trim line.[0] = '#' -> List.rev acc
      | Some line -> aux (line :: acc)
      | None -> List.rev acc
  in aux [] with
    | Parse_error msg -> raise (Parse_error ("Failed to read field: " ^ msg))
    | Sys_error msg -> raise (Parse_error ("Failed to read field: " ^ msg))

let parse_input (s: string list) (delimiter: char): (string * string) list =
  try let rec aux acc = function
    | [] -> List.rev acc
    | line :: rest -> 
        let part = String.split_on_char delimiter line in 
        match part with 
        | [left; right] -> aux ((String.trim left, String.trim right) :: acc) rest
        | _ -> raise (Parse_error ("Expected a pair of values separated by '" ^ delimiter ^ "', got: " ^ line))
  in aux [] with
    | Parse_error msg -> raise (Parse_error ("Failed to parse input: " ^ msg))
    | Sys_error msg -> raise (Parse_error ("Failed to parse input: " ^ msg))  

let parse_combos (s: string list): (string list * string) list =
  try let rec aux acc = function
    | [] -> List.rev acc
    | line :: rest -> 
        let parts = String.split_on_char ';' line in
        match parts with
        | [left; right] -> 
            let combo_paths = String.split_on_char ',' left in
            aux ((List.map String.trim combo_paths, String.trim right) :: acc) rest
        | _ -> raise (Parse_error ("Expected a pair of values separated by ';', got: " ^ line))
  in aux [] with
    | Parse_error msg -> raise (Parse_error ("Failed to parse combos: " ^ msg))
    | Sys_error msg -> raise (Parse_error ("Failed to parse combos: " ^ msg))

let as_char(s: string): char =
  if String.length s = 1 then
    s.[0]
  else
    raise (Parse_error ("Expected a single character, got: " ^ s))

