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

let string_of_finals (finals: (string * string)list) =
  let rec aux acc = function
    | [] -> acc
    | (state, combo_name) :: rest ->
      let new_acc = acc ^ Printf.sprintf "   %s is final for combo: %s\n" state combo_name in
      aux new_acc rest
    in aux "" finals

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

let expect condition message  = 
  if not condition then
    failwith message

let expect_equal expected actual message =
  expect (expected = actual) message 

let () =
  Printf.printf "training.ml\n%!";

  run "test training_01.gmr" (fun () ->
    let automata = Training.run_training "test/fixtures/training/training_01.gmr" in
    expect_equal [("s0", [("token2", "s4"); ("token1", "s1")]);
                  ("s1", [("token1", "s3"); ("token2", "s2")]);
                  ("s4", [("token3", "s5")])]
                automata.transitions
                "Failed to build transitions correctly";
    expect_equal [("s2", "combo_name1"); ("s3", "combo_name2"); ("s5", "combo_name3")]
                automata.finals
                "Failed to build finals correctly";
	  expect_equal [("key1", "token1"); ("key2", "token2"); ("key3", "token3")]
				        automata.input_map
				        "Failed to build input map correctly";
	  expect_equal "s0" 
                automata.initial
				        "Failed to set initial state correctly"
    );

  run "test training_02.gmr" (fun () ->
    let cool = Training.run_training "test/fixtures/training/training_02.gmr" in
    expect_equal [("s0", [("gang", "s8"); ("the", "s3"); ("cool", "s1")]);
                  ("s1", [("gang", "s7"); ("and", "s2")]);
                  ("s2", [("the", "s5")]);
                  ("s3", [("cool", "s10"); ("gang", "s4")]);
                  ("s5", [("gang", "s6")]);
                  ("s8", [("cool", "s12"); ("and", "s9")]);
                  ("s10", [("gang", "s11")])]
                  cool.transitions
                  "Failed to build transitions correctly";
    expect_equal       ("s7", "cool_gang"); ("s9", "gang_and"); ("s10", "the_cool");
                  ("s11", "the_cool_gang"); ("s12", "gang_cool")]
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