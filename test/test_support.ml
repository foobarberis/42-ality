type suite = {
  total : int ref;
  failed : int ref;
}

let write channel message =
  output_string channel message;
  flush channel

let number value =
  let text = string_of_int value in
  if value < 10 then "0" ^ text else text

let start name =
  write stdout (name ^ "\n");
  {total = ref 0; failed = ref 0}

let fail suite name message =
  incr suite.failed;
  write stderr
    ("[unit] [" ^ number !(suite.total) ^ "] FAIL " ^ name
     ^ "\n  " ^ message ^ "\n")

let run suite name test =
  incr suite.total;
  try
    test ();
    write stdout
      ("[unit] [" ^ number !(suite.total) ^ "] OK " ^ name ^ "\n")
  with
  | Failure message -> fail suite name message
  | Sys_error message -> fail suite name message
  (* The allowlist has no generic exception renderer. *)
  | _ -> fail suite name "unexpected exception"

let expect condition message =
  if not condition then failwith message

let expect_equal expected actual message =
  expect (expected = actual) message

let quote value =
  "\"" ^ String.escaped value ^ "\""

let temporary_counter = ref 0

(* Generate paths directly because temporary-file helpers are outside the allowlist. *)
let temporary_path prefix suffix =
  incr temporary_counter;
  let path =
    "_build/" ^ prefix ^ string_of_int !temporary_counter ^ suffix
  in
  if Sys.file_exists path then Sys.remove path;
  path

let remove_if_present path =
  if Sys.file_exists path then Sys.remove path

let with_grammar ~prefix contents test =
  let path = temporary_path prefix ".gmr" in
  let output = open_out path in
  try
    output_string output contents;
    close_out output;
    let result = test path in
    remove_if_present path;
    result
  with error ->
    close_out_noerr output;
    remove_if_present path;
    raise error

let read_file path =
  let channel = open_in path in
  try
    let contents = really_input_string channel (in_channel_length channel) in
    close_in channel;
    contents
  with error ->
    close_in_noerr channel;
    raise error

let finish suite =
  let ok = !(suite.total) - !(suite.failed) in
  write stdout
    ("SUMMARY: " ^ string_of_int ok ^ " OK / "
     ^ string_of_int !(suite.failed) ^ " FAIL\n");
  if !(suite.failed) <> 0 then exit 1
