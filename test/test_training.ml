let suite = Test_support.start "training.ml"
let run = Test_support.run suite
let expect_equal = Test_support.expect_equal

let () =
  run "test training_01.gmr" (fun () ->
    let automata =
      Training.Training.run_training "test/fixtures/training/training_01.gmr"
    in
    expect_equal [("s0", [("token2", "s4"); ("token1", "s1")]);
                  ("s1", [("token1", "s3"); ("token2", "s2")]);
                  ("s4", [("token3", "s5")])]
                automata.transitions
                "Failed to build transitions correctly";
    expect_equal [("s2", "combo_name1"); ("s3", "combo_name2"); ("s5", "combo_name3")]
                automata.finals
                "Failed to build finals correctly";
	  expect_equal [("1", "token1"); ("2", "token2"); ("3", "token3")]
				        automata.input_map
				        "Failed to build input map correctly";
	  expect_equal "s0" 
                automata.initial
				        "Failed to set initial state correctly"
    );

  run "test training_02.gmr" (fun () ->
    let cool =
      Training.Training.run_training "test/fixtures/training/training_02.gmr"
    in
    expect_equal [("s0", [("gang", "s8"); ("the", "s3"); ("cool", "s1")]);
                  ("s1", [("gang", "s7"); ("and", "s2")]);
                  ("s2", [("the", "s5")]);
                  ("s3", [("cool", "s10"); ("gang", "s4")]);
                  ("s5", [("gang", "s6")]);
                  ("s8", [("cool", "s12"); ("and", "s9")]);
                  ("s10", [("gang", "s11")])]
                  cool.transitions
                  "Failed to build transitions correctly";
    expect_equal [("s2", "cool_and"); ("s4", "the_gang");
                  ("s6", "cool_and_the_gang"); ("s7", "cool_gang");
                  ("s9", "gang_and"); ("s10", "the_cool");
                  ("s11", "the_cool_gang"); ("s12", "gang_cool")]
                  cool.finals
                  "Failed to build finals correctly";
    expect_equal [("a", "cool"); ("b", "and"); ("c", "the"); ("d", "gang")]
                  cool.input_map
                  "Failed to build input map correctly";
    expect_equal "s0"
                  cool.initial
                  "Failed to set initial state correctly"
    );

  run "return every move for a homonymous final state" (fun () ->
    let subject = Training.Training.run_training "res/subject.gmr" in
    match Automaton.Automata.step subject subject.initial "[BP]" with
    | None -> failwith "[BP] did not reach a final state"
    | Some bp_state ->
        expect_equal
          ["Claw Slam (Freddy Krueger)";
           "Knockdown (Sonya)";
           "Fist of Death (Liu-Kang)"]
          (Automaton.Automata.get_final_combos subject bp_state)
          "[BP] did not return all moves in grammar order";
        match Automaton.Automata.step subject bp_state "[FP]" with
        | None -> failwith "[BP], [FP] did not reach a final state"
        | Some bp_fp_state ->
            expect_equal
              ["Saibot Blast (Noob Saibot)";
               "Active Duty (Jax)"]
              (Automaton.Automata.get_final_combos subject bp_fp_state)
              "[BP], [FP] did not return all moves in grammar order"
    );

  Test_support.finish suite
