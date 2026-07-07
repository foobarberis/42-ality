open Training

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

let expect_transition condition message actual expected = 
  let msg = message ^ "\n actual:\n" ^ string_of_transitions actual ^ " expected:\n" ^ string_of_transitions expected in
  if not condition then
    failwith msg

let expect condition message  = 
  if not condition then
    failwith message

let expect_equal_transitions expected actual message =
  expect_transition (expected = actual) message actual expected

let expect_equal expected actual message =
  expect (expected = actual) message 

let () =
  Printf.printf "training.ml\n%!";

  run "test training_01.gmr" (fun () ->
    let automata = Training.run_training "test/fixtures/training/training_01.gmr" in
    expect_equal_transitions [("s0", [("token2", "s2"); ("token1", "s1")]);
                  ("s1", [("token1", "h1"); ("token2", "h0")]);
                  ("s2", [("token3", "h2")])]
                automata.transitions
                "Failed to build transitions correctly";
    expect_equal [("h0", "combo_name1"); ("h1", "combo_name2"); ("h2", "combo_name3")]
                automata.finals
                "Failed to build finals correctly";
	  expect_equal [("key1", "token1"); ("key2", "token2"); ("key3", "token3")]
				        automata.input_map
				        "Failed to build input map correctly";
	  expect_equal "s0" 
                automata.initial
				        "Failed to set initial state correctly"
    );

  run "test training_01.gmr" (fun () ->
    let cool = Training.run_training "test/fixtures/training/training_02.gmr" in
    expect_equal_transitions [("h0", [("the", "s3")]);
                  ("h5", [("gang", "h6")]);
                  ("s0", [("gang", "s4"); ("the", "s2"); ("cool", "s1")]);
                  ("s1", [("gang", "h3"); ("and", "h0")]);
                  ("s2", [("cool", "h5"); ("gang", "h1")]);
                  ("s3", [("gang", "h2")]);
                  ("s4", [("cool", "h7"); ("and", "h4")])]
                  cool.transitions
                  "Failed to build transitions correctly";
    expect_equal [("h0", "cool_and"); ("h1", "the_gang"); ("h2", "cool_and_the_gang");
                  ("h3", "cool_gang"); ("h4", "gang_and"); ("h5", "the_cool");
                  ("h6", "the_cool_gang"); ("h7", "gang_cool")]
                  cool.finals
                  "Failed to build finals correctly";
    expect_equal [("a", "cool"); ("b", "and"); ("c", "the"); ("d", "gang")]
                  cool.input_map
                  "Failed to build input map correctly";
    expect_equal "s0"
                  cool.initial
                  "Failed to set initial state correctly"; 
    );

  let ok = !total - !failed in 
  Printf.printf "SUMMARY: %d OK / %d FAIL\n%!" ok !failed;
  if !failed <> 0 then
    exit 1