let suite = Test_support.start "validate.ml"
let run = Test_support.run suite
let expect_equal = Test_support.expect_equal

let expect_validation_error validate =
  try
    validate ();
    failwith "expected Validation_error, but validation succeeded"
  with
  | Validate.Validation_error _ -> ()
  | _ ->
      failwith "expected Validation_error, got another exception"

let grammar key_map combos =
  {Parse.key_map = key_map; combos = combos}

let () =
  run "validate every resource grammar" (fun () ->
      List.iter
        (fun path ->
          path |> Parse.load_automaton |> Validate.validate_automaton)
        [ "res/subject.gmr";
          "res/common_prefix.gmr";
          "res/overlapping_sequences.gmr";
          "res/ten_word_sentence.gmr" ]);

  run "reject an empty input section" (fun () ->
      expect_validation_error (fun () ->
          Validate.validate_automaton (grammar [] [(["A"], "Move")])));

  run "reject an empty combo section" (fun () ->
      expect_validation_error (fun () ->
          Validate.validate_automaton (grammar [("a", "A")] [])));

  run "reject duplicate physical keys" (fun () ->
      expect_validation_error (fun () ->
          Validate.validate_automaton
            (grammar
               [("a", "A"); ("a", "B")]
               [(["A"], "Move")])));

  run "allow duplicate input tokens" (fun () ->
      Validate.validate_automaton
        (grammar
           [("a", "A"); ("b", "A")]
           [(["A"], "Move")]));

  run "allow duplicate move names" (fun () ->
      Validate.validate_automaton
        (grammar
           [("a", "A"); ("b", "B")]
           [(["A"], "Move"); (["B"], "Move")]));

  run "reject undeclared combo tokens" (fun () ->
      expect_validation_error (fun () ->
          Validate.validate_automaton
            (grammar [("a", "A")] [(["A"; "B"], "Move")])));

  run "allow homonymous token sequences" (fun () ->
      Validate.validate_automaton
        (grammar
           [("a", "A")]
           [(["A"], "First Move"); (["A"], "Second Move")]));

  run "allow an exact duplicate combo entry" (fun () ->
      Validate.validate_automaton
        (grammar
           [("a", "A")]
           [(["A"], "Move"); (["A"], "Move")]));

  run "preserve all subject combos" (fun () ->
      let parsed = Parse.load_automaton "res/subject.gmr" in
      Validate.validate_automaton parsed;
      expect_equal 5
        (List.length parsed.Parse.combos)
        "subject combo entries were removed";
      expect_equal
        [ "Claw Slam (Freddy Krueger)";
          "Knockdown (Sonya)";
          "Fist of Death (Liu-Kang)";
          "Saibot Blast (Noob Saibot)";
          "Active Duty (Jax)" ]
        (List.map snd parsed.Parse.combos)
        "subject combo order changed");

  run "format inputs and combos in grammar order" (fun () ->
      let parsed =
        grammar
          [("q", "Block"); ("down", "Down")]
          [(["Block"], "Guard"); (["Block"; "Down"], "Low Guard")]
      in
      expect_equal
        "Possible inputs:\nq -> Block\ndown -> Down\n\nPossible combos:\nBlock -> Guard\nBlock, Down -> Low Guard\n----------------------\n"
        (Parse.string_of_grammar parsed)
        "formatted grammar did not preserve order");

  run "format homonymous moves on separate lines" (fun () ->
      let parsed =
        grammar
          [("a", "A")]
          [(["A"], "First Move"); (["A"], "Second Move")]
      in
      expect_equal
        "Possible inputs:\na -> A\n\nPossible combos:\nA -> First Move\nA -> Second Move\n----------------------\n"
        (Parse.string_of_grammar parsed)
        "homonymous moves were not formatted separately");

  run "print nothing before semantic validation succeeds" (fun () ->
      Test_support.with_grammar ~prefix:"ft_ality_validate_"
        "#input\na;A\na;B\n#combos\nA;Move\n"
        (fun grammar_path ->
          let output_path =
            Test_support.temporary_path "ft_ality_output_" ".txt"
          in
          let output = open_out output_path in
          try
            expect_validation_error (fun () ->
                ignore
                  (Training.run_training
                     ~output grammar_path));
            close_out output;
            let contents = Test_support.read_file output_path in
            Test_support.remove_if_present output_path;
            expect_equal "" contents
              "invalid grammar printed possible inputs or combos"
          with error ->
            close_out_noerr output;
            Test_support.remove_if_present output_path;
            raise error));

  run "print nothing when parsing fails" (fun () ->
      Test_support.with_grammar ~prefix:"ft_ality_validate_"
        "#input\na;A\n"
        (fun grammar_path ->
          let output_path =
            Test_support.temporary_path "ft_ality_output_" ".txt"
          in
          let output = open_out output_path in
          try
            begin
              try
                ignore
                  (Training.run_training
                     ~output grammar_path);
                failwith "expected Parse_error, but training succeeded"
              with
              | Parse.Parse_error _ -> ()
            end;
            close_out output;
            let contents = Test_support.read_file output_path in
            Test_support.remove_if_present output_path;
            expect_equal "" contents
              "malformed grammar printed possible inputs or combos"
          with error ->
            close_out_noerr output;
            Test_support.remove_if_present output_path;
            raise error));

  Test_support.finish suite
