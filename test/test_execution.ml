let total = ref 0
let failed = ref 0

let fail name message =
  incr failed;
  Printf.eprintf "[unit] [%02d] FAIL %s\n  %s\n%!" !total name message

let run name test =
  incr total;
  try
    test ();
    Printf.printf "[unit] [%02d] OK %s\n%!" !total name
  with
  | Failure message -> fail name message
  | exn -> fail name (Printexc.to_string exn)

let expect condition message =
  if not condition then failwith message

let expect_equal expected actual message =
  expect (expected = actual) message

let build combos =
  Automaton.AutomataBuilder.buildAutomata "test"
  |> Automaton.AutomataBuilder.buildInitial "s0"
  |> Automaton.TransitionBuilder.trainingAutomata combos
  |> Automaton.TransitionBuilder.sort_automata

let () =
  Printf.printf "execution.ml\n%!";

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

  run "return every homonymous move in order" (fun () ->
      let automaton =
        build
          [(["A"], "First Move");
           (["A"], "Second Move")]
      in
      let result =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["A"] result.Execution.next.sequence
        "recognized sequence was not retained";
      expect_equal ["First Move"; "Second Move"]
        result.Execution.recognized
        "homonymous moves were not returned in order");

  run "retain a final prefix for a longer move" (fun () ->
      let automaton =
        build
          [(["A"], "Move A");
           (["A"; "B"], "Move AB")]
      in
      let first =
        Execution.handle_token automaton (Execution.initial automaton) "A"
      in
      expect_equal ["Move A"] first.Execution.recognized
        "the prefix move was not recognized";
      let second =
        Execution.handle_token automaton first.Execution.next "B"
      in
      expect_equal ["A"; "B"] second.Execution.next.sequence
        "the longer shared-prefix sequence was not retained";
      expect_equal ["Move AB"] second.Execution.recognized
        "the longer shared-prefix move was not recognized");

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

  run "do not reuse a token from a recognized move" (fun () ->
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

  let ok = !total - !failed in
  Printf.printf "SUMMARY: %d OK / %d FAIL\n%!" ok !failed;
  if !failed <> 0 then exit 1
