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

let run grammarfile =
  if not (can_read_file grammarfile) then
    begin
      prerr_endline ("Error: cannot read grammar file: " ^ grammarfile);
      1
    end
  else
    begin
      ignore (Training.Training.run_training grammarfile);
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

let arguments () =
  match Sys.argv with
  | [| _; argument |] -> [argument]
  | _ -> []

let main () =
  match parse_args (arguments ()) with
  | Help ->
      print_usage stdout;
      0
  | Run grammarfile ->
      run grammarfile
  | Error ->
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
  | Validate.Validation_error message ->
    prerr_endline ("Error: " ^ message);
    exit 1
  | _ ->
    prerr_endline "Error: unexpected failure";
    exit 1

