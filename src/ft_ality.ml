let usage =
  "usage: ft_ality grammarfile\n\n"
  ^ "positional arguments:\n"
  ^ "  grammarfile    grammar used to train the automaton\n\n"
  ^ "optional arguments:\n"
  ^ "  -h, --help     show this help message and exit"

let print_usage channel =
  output_string channel (usage ^ "\n")

(* Train the automaton and always restore the terminal after running it. *)
let run grammarfile =
  let automaton = Training.run_training grammarfile in
  flush stdout;
  Keyboard.init ();
  try
    Runtime.run Keyboard.read_event stdout automaton;
    Keyboard.shutdown ();
    0
  with
  | error ->
      Keyboard.shutdown ();
      raise error

type cli =
  | Help
  | Run of string
  | Error

(* Accept one grammar path, or a help option on its own. *)
let parse_args args =
  match args with
  | ["-h"] | ["--help"] -> Help
  | [grammarfile] -> Run grammarfile
  | _ -> Error

(* Read the only supported positional argument. *)
let arguments () =
  match Sys.argv with
  | [| _; argument |] -> [argument]
  | _ -> []

(* Run the command and return its exit status. *)
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

