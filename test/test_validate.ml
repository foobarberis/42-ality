open Validate

let total = ref 0
let failed = ref 0

let fail name message =
  incr failed;
   Printf.eprintf "[unit] [%02d] FAIL %s\n  %s\n%!" !total name message

let run name f =
  incr total;
  try
    f ();
    Printf.printf "[unit] [%02d] OK %s\n%!" !total name
  with
  | Failure message -> fail name message
  | exn -> fail name (Printexc.to_string exn)

let expect condition message = 
  if not condition then
    failwith message

let expect_equal expected actual message =
  expect (expected = actual) message

let expect_Validation_error f =
  try
    let _ = f () in
    failwith "Expected validation error, but validation succeeded"
  with
  | Validation_error _ -> ()
  | exn -> failwith ("Expected validation error, but got: " ^ Printexc.to_string exn)

let () = 
  Printf.printf "validate.ml\n%!";

  run "Validate input_map with duplicates" (fun () ->
    expect_Validation_error (function () -> 
      validate_input [("key1", "token1"); ("key1", "token2")]));

  run "Validate combos with duplicates combo_names" (fun () ->
    expect_Validation_error (function () -> 
      validate_combos_name [(["key1"; "key2"], "combo1"); (["key3"; "key4"], "combo1")]));

  let ok = !total - !failed in 
    Printf.printf "SUMMARY: %d OK / %d FAIL\n%!" ok !failed;
    if !failed <> 0 then
      exit 1