open Parse

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

let expect_parse_error f =
  try
    let _ = f () in
    failwith "Expected parse error, but parsing succeeded"
  with
  | Parse_error _ -> ()
  | exn -> failwith ("Expected parse error, but got: " ^ Printexc.to_string exn)

let () = 
  Printf.printf "parse.ml\n%!";

  run "load_grammar reject missing file" (fun () ->
    expect_parse_error (fun () -> load_grammar "test/fixtures/parse/missing.gmr"));

  (*TODO remove read access to test/fixtures/parse/access_corrupt.gmr file*)
  run "load_grammar reject access file" (fun () -> 
    expect_parse_error (fun () -> load_grammar "test/fixtures/parse/access_corrupt.gmr"));

  run "field 'input'" (fun () ->
    let in_channel = load_grammar "test/fixtures/parse/good_synthax.gmr" in
    expect_equal
      ["key1;token1";
      "key2;token2";
      "key3;token3";
      "key4;token4"]
      (field "input" in_channel)
      "Failed to execute field function"
    );

  run "field 'input' reject none 'input' field" (fun () -> 
  let in_channel = load_grammar "test/fixtures/parse/missing_input.gmr" in
  expect_parse_error
    (fun () -> field "input" in_channel));

  run "field 'combos'" (fun () -> 
  let in_channel = load_grammar "test/fixtures/parse/good_synthax.gmr" in
  expect_equal
    ["key1,key2,key3;combo_name1";
    "key1,key2,key3,key4;combo_name2";
    "key1,key2,key3,key4;combo_name3"]
    (field "combos" in_channel)
    "Failed to execute field function"
    );

  run "parse_input '[left;right]'" (fun () ->
    expect_equal 
      ["left", "right"] 
      (parse_input ["left;right"] ';') 
      "Failed to parse input"
  );

  run "parse_input '[left;right] with spaces'" (fun () ->
    expect_equal 
      ["left", "right"]
      (parse_input ["  left  ;  right  "] ';')
      "Failed to parse input"
  );

  run "parse_input '[left;right] with extra parts'" (fun () ->
    expect_parse_error
      (fun () -> parse_input ["Left;Right;Extra"] ';')
  );

  run "parse_input '[left;right] with missing parts'" (fun () ->
    expect_parse_error
      (fun () -> parse_input ["Left"] ';')
  );

  run "parse_input '[left;right] with empty string'" (fun () ->
    expect_parse_error
      (fun () -> parse_input [""] ';')
  );

  run "parse_combos '[left1,left2;right]'" (fun () ->
    expect_equal 
      [(["left1"; "left2"], "right")] 
      (parse_combos ["left1,left2;right"])
      "Failed to parse combos"
  );
  
  run "parse_combos '[left1,left2;right] with spaces'" (fun () ->
	  expect_equal 
      [(["left1"; "left2"], "right")] 
      (parse_combos ["  left1 , left2  ;  right  "])
      "Failed to parse combos"
  );

  let ok = !total - !failed in 
  Printf.printf "SUMMARY: %d OK / %d FAIL\n%!" ok !failed;
  if !failed <> 0 then
    exit 1