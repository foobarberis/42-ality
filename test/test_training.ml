let suite = Test_support.start "training.ml"
let run = Test_support.run suite
let expect = Test_support.expect
let expect_equal = Test_support.expect_equal

let train path =
  let output = open_out "/dev/null" in
  try
    let automaton = Training.run_training ~output path in
    close_out output;
    automaton
  with error ->
    close_out_noerr output;
    raise error

let follow automaton state token =
  match Automaton.follow automaton state token with
  | Some next -> next
  | None -> failwith ("missing transition for " ^ token)

let follow_sequence automaton tokens =
  List.fold_left (follow automaton) automaton.Automaton.initial tokens

let expect_move automaton tokens move =
  let state = follow_sequence automaton tokens in
  expect_equal [move] (Automaton.recognized automaton state)
    (String.concat ", " tokens ^ " did not recognize " ^ move)

let () =
  run "train the first fixture by behavior" (fun () ->
      let automaton = train "test/fixtures/training/training_01.gmr" in
      expect (automaton.Automaton.initial <> "")
        "automaton did not have an initial state";
      expect (automaton.Automaton.transitions <> [])
        "automaton did not have transitions";
      expect (automaton.Automaton.finals <> [])
        "automaton did not have final states";
      expect_equal (Some "token1")
        (Automaton.resolve_key automaton "1")
        "key 1 was not resolved";
      expect_equal (Some "token2")
        (Automaton.resolve_key automaton "2")
        "key 2 was not resolved";
      expect_equal (Some "token3")
        (Automaton.resolve_key automaton "3")
        "key 3 was not resolved";
      expect_move automaton ["token1"; "token2"] "combo_name1";
      expect_move automaton ["token1"; "token1"] "combo_name2";
      expect_move automaton ["token2"; "token3"] "combo_name3");

  run "train the second fixture by behavior" (fun () ->
      let automaton = train "test/fixtures/training/training_02.gmr" in
      expect_equal (Some "cool")
        (Automaton.resolve_key automaton "a")
        "key a was not resolved";
      expect_equal (Some "and")
        (Automaton.resolve_key automaton "b")
        "key b was not resolved";
      expect_equal (Some "the")
        (Automaton.resolve_key automaton "c")
        "key c was not resolved";
      expect_equal (Some "gang")
        (Automaton.resolve_key automaton "d")
        "key d was not resolved";
      expect_move automaton ["cool"; "and"] "cool_and";
      expect_move automaton ["the"; "gang"] "the_gang";
      expect_move automaton ["cool"; "and"; "the"; "gang"]
        "cool_and_the_gang";
      expect_move automaton ["cool"; "gang"] "cool_gang";
      expect_move automaton ["gang"; "and"] "gang_and";
      expect_move automaton ["the"; "cool"] "the_cool";
      expect_move automaton ["the"; "cool"; "gang"] "the_cool_gang";
      expect_move automaton ["gang"; "cool"] "gang_cool");

  run "share states between prefix moves" (fun () ->
      let automaton = train "test/fixtures/training/training_02.gmr" in
      let cool_state = follow_sequence automaton ["cool"] in
      let cool_and_state = follow automaton cool_state "and" in
      expect_equal ["cool_and"]
        (Automaton.recognized automaton cool_and_state)
        "the shorter shared-prefix move was not recognized";
      let cool_and_the_state = follow automaton cool_and_state "the" in
      let cool_and_the_gang_state =
        follow automaton cool_and_the_state "gang"
      in
      expect_equal ["cool_and_the_gang"]
        (Automaton.recognized automaton cool_and_the_gang_state)
        "the longer shared-prefix move was not recognized");

  run "return every move for a homonymous final state" (fun () ->
      let automaton = train "res/subject.gmr" in
      let bp_state = follow automaton automaton.Automaton.initial "[BP]" in
      expect_equal
        ["Claw Slam (Freddy Krueger)";
         "Knockdown (Sonya)";
         "Fist of Death (Liu-Kang)"]
        (Automaton.recognized automaton bp_state)
        "[BP] did not return all moves in grammar order";
      let bp_fp_state = follow automaton bp_state "[FP]" in
      expect_equal
        ["Saibot Blast (Noob Saibot)";
         "Active Duty (Jax)"]
        (Automaton.recognized automaton bp_fp_state)
        "[BP], [FP] did not return all moves in grammar order");

  Test_support.finish suite
