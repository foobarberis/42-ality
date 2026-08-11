let suite = Test_support.start "execution.ml"
let run = Test_support.run suite
let expect = Test_support.expect
let expect_equal = Test_support.expect_equal

let build combos =
  Automaton.create [] combos

let moves automaton state =
  Automaton.recognized automaton state.Execution.automaton_state

let () =
  run "initialize execution at the automaton start" (fun () ->
      let automaton = build [(["A"], "Move A")] in
      let state = Execution.initial automaton in
      expect_equal automaton.Automaton.initial
        state.Execution.automaton_state
        "execution did not start at the initial state";
      expect_equal [] (Execution.sequence state)
        "initial execution sequence was not empty");

  run "advance without side effects before recognition" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let state = Execution.initial automaton in
      let next = Execution.advance automaton state "A" in
      expect_equal ["A"] (Execution.sequence next)
        "the current token was not added to the sequence";
      expect_equal [] (moves automaton next)
        "a non-final state recognized a move";
      expect_equal [] (Execution.sequence state)
        "handling a token changed the previous state");

  run "recognize a single-token move" (fun () ->
      let automaton = build [(["A"], "Move A")] in
      let state =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["A"] (Execution.sequence state)
        "the single-token sequence was not retained";
      expect_equal ["Move A"] (moves automaton state)
        "the single-token move was not recognized");

  run "return every homonymous move" (fun () ->
      let automaton =
        build
          [(["A"], "First Move");
           (["A"], "Second Move")]
      in
      let state =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["First Move"; "Second Move"]
        (moves automaton state)
        "not every homonymous move was returned");

  run "preserve homonymous move recognition order" (fun () ->
      let automaton =
        build
          [(["A"], "First Move");
           (["B"], "Other Move");
           (["A"], "Second Move");
           (["A"], "Third Move")]
      in
      let state =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["First Move"; "Second Move"; "Third Move"]
        (moves automaton state)
        "homonymous moves were not returned in grammar order");

  run "recognize final moves that remain common prefixes" (fun () ->
      let automaton =
        build
          [(["A"], "Move A");
           (["A"; "B"], "Move AB");
           (["A"; "B"; "A"], "Move ABA")]
      in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["Move A"] (moves automaton first)
        "the first prefix move was not recognized";
      expect (Automaton.has_outgoing automaton first.Execution.automaton_state)
        "the recognized prefix could not continue";
      let second = Execution.handle_token automaton first "B" in
      expect_equal ["A"; "B"] (Execution.sequence second)
        "the second common-prefix sequence was not retained";
      expect_equal ["Move AB"] (moves automaton second)
        "the second prefix move was not recognized";
      let third = Execution.handle_token automaton second "A" in
      expect_equal ["A"; "B"; "A"] (Execution.sequence third)
        "the longest common-prefix sequence was not retained";
      expect_equal ["Move ABA"] (moves automaton third)
        "the longest prefix move was not recognized");

  run "retry only a failed token from the start" (fun () ->
      let automaton =
        build
          [(["A"; "B"], "Move AB");
           (["C"], "Move C")]
      in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let second = Execution.handle_token automaton first "C" in
      expect_equal ["C"] (Execution.sequence second)
        "the abandoned sequence was not discarded";
      expect_equal ["Move C"] (moves automaton second)
        "the failed token was not retried from the start");

  run "do not recognize overlapping sequences" (fun () ->
      let automaton =
        build
          [(["A"; "B"], "Move AB");
           (["B"; "C"], "Move BC")]
      in
      let after_a =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let after_b = Execution.handle_token automaton after_a "B" in
      expect_equal ["Move AB"] (moves automaton after_b)
        "Move AB was not recognized";
      let after_c = Execution.handle_token automaton after_b "C" in
      expect_equal [] (Execution.sequence after_c)
        "the B from Move AB was reused for Move BC";
      expect_equal [] (moves automaton after_c)
        "overlapping Move BC was incorrectly recognized");

  run "reset after a token that cannot start a sequence" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let state = Execution.handle_token automaton first "X" in
      expect_equal automaton.Automaton.initial
        state.Execution.automaton_state
        "invalid input did not return to the initial state";
      expect_equal [] (Execution.sequence state)
        "invalid input did not clear the sequence";
      expect_equal [] (moves automaton state)
        "invalid input recognized a move");

  run "ignore a completely invalid sequence" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "X"
      in
      let second = Execution.handle_token automaton first "Y" in
      let third = Execution.handle_token automaton second "Z" in
      expect_equal automaton.Automaton.initial
        third.Execution.automaton_state
        "invalid tokens moved away from the initial state";
      expect_equal
        [[]; []; []]
        [Execution.sequence first;
         Execution.sequence second;
         Execution.sequence third]
        "invalid tokens were retained in the sequence";
      expect_equal [] (moves automaton first)
        "the first invalid token recognized a move";
      expect_equal [] (moves automaton second)
        "the second invalid token recognized a move";
      expect_equal [] (moves automaton third)
        "the third invalid token recognized a move");

  run "recognize repeated moves" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let second = Execution.handle_token automaton first "B" in
      let third = Execution.handle_token automaton second "A" in
      let fourth = Execution.handle_token automaton third "B" in
      expect_equal ["Move AB"] (moves automaton second)
        "the first occurrence was not recognized";
      expect_equal ["A"] (Execution.sequence third)
        "the repeated move did not restart from the initial state";
      expect_equal ["Move AB"] (moves automaton fourth)
        "the repeated occurrence was not recognized";
      expect_equal ["A"; "B"] (Execution.sequence fourth)
        "the repeated sequence was not retained");

  run "reset explicitly" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let state = Execution.reset automaton in
      expect (state <> result)
        "reset retained the current execution state";
      expect_equal automaton.Automaton.initial
        state.Execution.automaton_state
        "reset did not return to the initial state";
      expect_equal [] (Execution.sequence state)
        "reset did not clear the sequence");

  Test_support.finish suite
