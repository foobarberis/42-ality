let suite = Test_support.start "execution.ml"
let run = Test_support.run suite
let expect = Test_support.expect
let expect_equal = Test_support.expect_equal

let build combos =
  Automaton.AutomataBuilder.buildAutomata "test"
  |> Automaton.AutomataBuilder.buildInitial "s0"
  |> Automaton.TransitionBuilder.trainingAutomata combos
  |> Automaton.TransitionBuilder.sort_automata

let () =
  run "initialize execution at the automaton start" (fun () ->
      let automaton = build [(["A"], "Move A")] in
      let state = Execution.initial automaton in
      expect_equal automaton.Automaton.AutomataTypes.initial
        state.Execution.automaton_state
        "execution did not start at the initial state";
      expect_equal [] state.Execution.sequence
        "initial execution sequence was not empty");

  run "advance without side effects before recognition" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let state = Execution.initial automaton in
      let result = Execution.handle_token automaton state "A" in
      expect_equal ["A"] result.Execution.next.sequence
        "the current token was not added to the sequence";
      expect_equal [] result.Execution.recognized
        "a non-final state recognized a move";
      expect_equal [] state.Execution.sequence
        "handling a token changed the previous state");

  run "recognize a single-token move" (fun () ->
      let automaton = build [(["A"], "Move A")] in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["A"] result.Execution.next.sequence
        "the single-token sequence was not retained";
      expect_equal ["Move A"] result.Execution.recognized
        "the single-token move was not recognized");

  run "return every homonymous move" (fun () ->
      let automaton =
        build
          [(["A"], "First Move");
           (["A"], "Second Move")]
      in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["First Move"; "Second Move"]
        result.Execution.recognized
        "not every homonymous move was returned");

  run "preserve homonymous move recognition order" (fun () ->
      let automaton =
        build
          [(["A"], "First Move");
           (["B"], "Other Move");
           (["A"], "Second Move");
           (["A"], "Third Move")]
      in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["First Move"; "Second Move"; "Third Move"]
        result.Execution.recognized
        "homonymous moves were not returned in grammar order");

  run "recognize every move along a common prefix" (fun () ->
      let automaton =
        build
          [(["A"], "Move A");
           (["A"; "B"], "Move AB");
           (["A"; "B"; "A"], "Move ABA")]
      in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["Move A"] first.Execution.recognized
        "the first prefix move was not recognized";
      let second =
        Execution.handle_token automaton first.Execution.next "B"
      in
      expect_equal ["A"; "B"] second.Execution.next.sequence
        "the second common-prefix sequence was not retained";
      expect_equal ["Move AB"] second.Execution.recognized
        "the second prefix move was not recognized";
      let third =
        Execution.handle_token automaton second.Execution.next "A"
      in
      expect_equal ["A"; "B"; "A"] third.Execution.next.sequence
        "the longest common-prefix sequence was not retained";
      expect_equal ["Move ABA"] third.Execution.recognized
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
      let second =
        Execution.handle_token automaton first.Execution.next "C"
      in
      expect_equal ["C"] second.Execution.next.sequence
        "the abandoned sequence was not discarded";
      expect_equal ["Move C"] second.Execution.recognized
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
      let after_b =
        Execution.handle_token automaton after_a.Execution.next "B"
      in
      expect_equal ["Move AB"] after_b.Execution.recognized
        "Move AB was not recognized";
      let after_c =
        Execution.handle_token automaton after_b.Execution.next "C"
      in
      expect_equal [] after_c.Execution.next.sequence
        "the B from Move AB was reused for Move BC";
      expect_equal [] after_c.Execution.recognized
        "overlapping Move BC was incorrectly recognized");

  run "reset after a token that cannot start a sequence" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let result =
        Execution.handle_token automaton first.Execution.next "X"
      in
      expect_equal automaton.Automaton.AutomataTypes.initial
        result.Execution.next.automaton_state
        "invalid input did not return to the initial state";
      expect_equal [] result.Execution.next.sequence
        "invalid input did not clear the sequence";
      expect_equal [] result.Execution.recognized
        "invalid input recognized a move");

  run "ignore a completely invalid sequence" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "X"
      in
      let second =
        Execution.handle_token automaton first.Execution.next "Y"
      in
      let third =
        Execution.handle_token automaton second.Execution.next "Z"
      in
      expect_equal automaton.Automaton.AutomataTypes.initial
        third.Execution.next.automaton_state
        "invalid tokens moved away from the initial state";
      expect_equal
        [[]; []; []]
        [first.Execution.next.sequence;
         second.Execution.next.sequence;
         third.Execution.next.sequence]
        "invalid tokens were retained in the sequence";
      expect_equal [] first.Execution.recognized
        "the first invalid token recognized a move";
      expect_equal [] second.Execution.recognized
        "the second invalid token recognized a move";
      expect_equal [] third.Execution.recognized
        "the third invalid token recognized a move");

  run "recognize repeated moves" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let second =
        Execution.handle_token automaton first.Execution.next "B"
      in
      let third =
        Execution.handle_token automaton second.Execution.next "A"
      in
      let fourth =
        Execution.handle_token automaton third.Execution.next "B"
      in
      expect_equal ["Move AB"] second.Execution.recognized
        "the first occurrence was not recognized";
      expect_equal ["A"] third.Execution.next.sequence
        "the repeated move did not restart from the initial state";
      expect_equal ["Move AB"] fourth.Execution.recognized
        "the repeated occurrence was not recognized";
      expect_equal ["A"; "B"] fourth.Execution.next.sequence
        "the repeated sequence was not retained");

  run "reset explicitly" (fun () ->
      let automaton = build [(["A"; "B"], "Move AB")] in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      let state = Execution.reset automaton in
      expect (state <> result.Execution.next)
        "reset retained the current execution state";
      expect_equal automaton.Automaton.AutomataTypes.initial
        state.Execution.automaton_state
        "reset did not return to the initial state";
      expect_equal [] state.Execution.sequence
        "reset did not clear the sequence");

  Test_support.finish suite
