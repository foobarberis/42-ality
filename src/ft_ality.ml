let usage =
  "usage: ft_ality grammarfile\n\n"
  ^ "positional arguments:\n"
  ^ "  grammarfile    grammar used to train the automaton\n\n"
  ^ "optional arguments:\n"
  ^ "  -h, --help     show this help message and exit"

let print_usage channel =
  output_string channel (usage ^ "\n")

let can_read_file path =
  try
    if Sys.file_exists path && not (Sys.is_directory path) then
      let channel = open_in path in
      close_in channel;
      true
    else
      false
  with
  | Sys_error _ -> false

let string_of_transitions (transition: (string * (string * string)list)list) =
  let rec aux acc = function
    | [] -> acc
    | (state, transitions) :: rest ->
      let transition_str = List.map
          (fun (input, next_state) -> Printf.sprintf "    %s --%s--> %s" state input next_state) 
          transitions
        in
        let new_acc = acc ^ String.concat "\n" transition_str ^ "\n" in
        aux new_acc rest
  in aux "" transition

let string_of_finals (finals: (string * string)list) =
  let rec aux acc = function
    | [] -> acc
    | (state, combo_name) :: rest ->
      let new_acc = acc ^ Printf.sprintf "   %s is final for combo: %s\n" state combo_name in
      aux new_acc rest
    in aux "" finals

let run grammarfile =
  if not (can_read_file grammarfile) then
    begin
      prerr_endline ("Error: cannot read grammar file: " ^ grammarfile);
      1
    end
  else
    begin
      let automate = Training.Training.run_training grammarfile in
      print_endline (string_of_transitions automate.Automaton.AutomataTypes.transitions);
      print_endline (string_of_finals automate.Automaton.AutomataTypes.finals);
      print_endline ("Automata name: " ^ automate.Automaton.AutomataTypes.name);
      print_endline ("Automata name: " ^ automate.Automaton.AutomataTypes.name);
      print_endline ("Grammar file: " ^ grammarfile);
      print_endline "Parsing/training will be connected here.";
      print_endline "Execution loop will be connected here.";
      0
    end

type cli =
  | Help
  | Run of string
  | Error

let parse_args args =
  match args with
  | ["-h"] | ["--help"] -> Help
  | [grammarfile] -> Run grammarfile
  | _ -> Error

let main () =
  match Array.to_list Sys.argv with
  | _ :: args ->
      begin
        match parse_args args with
        | Help ->
            print_usage stdout;
            0
        | Run grammarfile ->
            run grammarfile
        | Error ->
            print_usage stderr;
            1
      end
  | [] ->
      print_usage stderr;
      1

let () =
  try exit (main ()) with
  | Sys_error message ->
      prerr_endline ("Error: " ^ message);
      exit 1
  | Failure message ->
      prerr_endline ("Error: " ^ message);
      exit 1
  | Parse.Parse_error message -> 
    prerr_endline ("Error: " ^ message);
    exit 1
  | _ ->
    prerr_endline "Error: unexpected failure";
    exit 1

