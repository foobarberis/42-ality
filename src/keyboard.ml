let timeout_deciseconds = 3

let terminal_active = ref false
let state_file = ref None
let state_directory = ref None
let pending_character = ref None
let pending_characters = ref []
let previous_sigint = ref Sys.Signal_default
let previous_sigterm = ref Sys.Signal_default

(* Remove the temporary copy of the terminal mode. *)
let remove_state_file () =
  begin
    match !state_file with
    | Some path ->
        state_file := None;
        begin
          try Sys.remove path with
          | Sys_error _ -> ()
        end
    | None -> ()
  end;
  begin
    match !state_directory with
    | Some path ->
        state_directory := None;
        ignore (Sys.command ("rmdir " ^ path ^ " 2>/dev/null"))
    | None -> ()
  end

(* Restore the terminal mode saved before interactive input began. *)
let restore_saved_mode () =
  match !state_file with
  | Some path ->
      ignore (Sys.command ("stty $(cat " ^ path ^ ") 2>/dev/null"))
  | None -> ()

(* Restore the terminal once, then remove the saved mode. *)
let restore_terminal () =
  if !terminal_active then
    begin
      terminal_active := false;
      restore_saved_mode ();
      remove_state_file ()
    end

(* Restore the terminal and the previous signal handlers. *)
let shutdown () =
  if !terminal_active then
    begin
      restore_terminal ();
      Sys.set_signal Sys.sigint !previous_sigint;
      Sys.set_signal Sys.sigterm !previous_sigterm
    end

(* Restore the terminal before exiting on an interrupt. *)
let handle_signal exit_code _ =
  restore_terminal ();
  exit exit_code

(* Read the PID used to name this process's state directory. *)
let process_id () =
  try
    let channel = open_in "/proc/self/stat" in
    let line = input_line channel in
    close_in_noerr channel;
    match String.split_on_char ' ' line with
    | identifier :: _ -> Some identifier
    | [] -> None
  with
  | End_of_file | Sys_error _ -> None

(* Create a private file for the saved stty mode. *)
let make_state_file () =
  match process_id () with
  | None -> None
  | Some identifier ->
      let directory = "/tmp/ft_ality." ^ identifier in
      let path = directory ^ "/mode" in
      let create_directory =
        "umask 077; mkdir " ^ directory ^ " 2>/dev/null"
      in
      if Sys.command create_directory <> 0 then
        None
      else if Sys.command ("umask 077; : > " ^ path ^ " 2>/dev/null") = 0 then
        begin
          state_directory := Some directory;
          Some path
        end
      else
        begin
          ignore (Sys.command ("rmdir " ^ directory ^ " 2>/dev/null"));
          None
        end

(* Enable timed, non-canonical input. Roll back all setup on failure. *)
let init () =
  if not !terminal_active then
    begin
      match make_state_file () with
      | None -> raise (Failure "interactive terminal required")
      | Some path ->
          state_file := Some path;
          (* Save the full mode before changing it. *)
          if Sys.command ("stty -g > " ^ path ^ " 2>/dev/null") <> 0 then
            begin
              remove_state_file ();
              raise (Failure "interactive terminal required")
            end;
          let command =
            "stty -echo -icanon min 0 time "
            ^ string_of_int timeout_deciseconds
            ^ " 2>/dev/null"
          in
          if Sys.command command <> 0 then
            begin
              restore_saved_mode ();
              remove_state_file ();
              raise (Failure "interactive terminal required")
            end;
          terminal_active := true;
          (* Restore the terminal on Ctrl-C or SIGTERM. *)
          previous_sigint :=
            Sys.signal Sys.sigint (Sys.Signal_handle (handle_signal 130));
          previous_sigterm :=
            Sys.signal Sys.sigterm (Sys.Signal_handle (handle_signal 143))
    end

(* Read buffered escape-sequence characters before reading stdin. *)
let read_character () =
  match !pending_character with
  | Some character ->
      pending_character := None;
      Some character
  | None ->
      begin
        match !pending_characters with
        | character :: rest ->
            pending_characters := rest;
            Some character
        | [] ->
            try Some (input_char stdin) with
            | End_of_file -> None
      end

(* Put a lookahead character back at the front of the buffer. *)
let unread_character character =
  match !pending_character with
  | None -> pending_character := Some character
  | Some pending ->
      pending_character := Some character;
      pending_characters := pending :: !pending_characters

(* Skip an unsupported CSI sequence through its final byte. *)
let rec discard_csi () =
  match read_character () with
  | Some character when character >= '@' && character <= '~' -> ()
  | Some _ -> discard_csi ()
  | None -> ()

(* Map an arrow sequence's final byte to a key event. *)
let arrow_event = function
  | 'A' -> Some (Runtime.Key "up")
  | 'B' -> Some (Runtime.Key "down")
  | 'C' -> Some (Runtime.Key "right")
  | 'D' -> Some (Runtime.Key "left")
  | _ -> None

(* Decode a CSI sequence and consume unsupported variants in full. *)
let read_csi () =
  match read_character () with
  | Some character ->
      begin
        match arrow_event character with
        | Some event -> event
        | None ->
            discard_csi ();
            Runtime.Unsupported_key
      end
  | None -> Runtime.Unsupported_key

(* Decode the SS3 arrow sequence used by some terminals. *)
let read_ss3 () =
  match read_character () with
  | Some character ->
      begin
        match arrow_event character with
        | Some event -> event
        | None -> Runtime.Unsupported_key
      end
  | None -> Runtime.Unsupported_key

(* Decode arrow sequences, but keep a lone Escape as a key press. *)
let read_escape_sequence () =
  match read_character () with
  | Some '[' -> read_csi ()
  | Some 'O' -> read_ss3 ()
  | Some character ->
      unread_character character;
      Runtime.Key "escape"
  | None -> Runtime.Key "escape"

(* Turn a terminal character into a runtime event or key alias. *)
let event_of_character character =
  match character with
  | '\004' -> Runtime.Quit
  | '\027' -> read_escape_sequence ()
  | '\008' | '\127' -> Runtime.Key "backspace"
  | '\009' -> Runtime.Key "tab"
  | '\010' | '\013' -> Runtime.Key "enter"
  | ' ' -> Runtime.Key "space"
  | ';' -> Runtime.Key "semicolon"
  | ',' -> Runtime.Key "comma"
  | '#' -> Runtime.Key "hash"
  | _ ->
      let code = int_of_char character in
      if code >= 33 && code <= 126 then
        Runtime.Key (String.make 1 character)
      else
        Runtime.Unsupported_key

(* Read one event; a timed read with no input becomes [Timeout]. *)
let read_event () =
  match read_character () with
  | Some character -> event_of_character character
  | None -> Runtime.Timeout
