type event =
  | Key of string
  | Unsupported_key
  | Ignored
  | Timeout
  | Quit

let print_sequence output sequence =
  output_string output (String.concat ", " sequence ^ "\n")

let rec print_moves output = function
  | [] -> ()
  | move :: rest ->
      output_string output (move ^ " !!\n");
      print_moves output rest

let print_result output sequence moves =
  print_sequence output sequence;
  print_moves output moves;
  flush output

(* Get the moves recognized in the current state. *)
let moves automaton state =
  Automaton.recognized automaton state.Execution.automaton_state

(* A completed move stays pending if more input could extend it. *)
let is_pending automaton state =
  moves automaton state <> []
  && Automaton.has_outgoing automaton state.Execution.automaton_state

(* Print a pending move once it can no longer continue. *)
let print_pending output automaton state =
  if is_pending automaton state then
    print_result output (Execution.sequence state) (moves automaton state)

(* Print a completed move now unless it could become a longer combo. *)
let print_or_delay output automaton state token =
  let sequence = Execution.sequence state in
  let displayed = if sequence = [] then [token] else sequence in
  if not (is_pending automaton state) then
    print_result output displayed (moves automaton state)

(* Handle events until quit. A timeout, invalid input, or broken sequence
   settles any pending move. *)
let rec loop read_event output automaton state =
  match read_event () with
  | Quit -> print_pending output automaton state
  | Ignored -> loop read_event output automaton state
  | Timeout ->
      (* A timeout settles a completed prefix that could have continued. *)
      if is_pending automaton state then
        begin
          print_pending output automaton state;
          loop read_event output automaton (Execution.reset automaton)
        end
      else
        loop read_event output automaton state
  | Unsupported_key ->
      (* Unsupported input ends the current sequence. *)
      print_pending output automaton state;
      loop read_event output automaton (Execution.reset automaton)
  | Key identifier ->
      begin
        match Automaton.resolve_key automaton identifier with
        | None ->
            print_pending output automaton state;
            print_result output [identifier] [];
            loop read_event output automaton (Execution.reset automaton)
        | Some token ->
            let continuation =
              Automaton.follow automaton state.Execution.automaton_state token
            in
            let current_state =
              (* Finish the shorter move before reusing this token. *)
              if is_pending automaton state && continuation = None then
                begin
                  print_pending output automaton state;
                  Execution.reset automaton
                end
              else
                state
            in
            let next_state =
              Execution.handle_token automaton current_state token
            in
            print_or_delay output automaton next_state token;
            loop read_event output automaton next_state
      end

(* Start recognizing input from the initial state. *)
let run read_event output automaton =
  loop read_event output automaton (Execution.initial automaton)
