let suite = Test_support.start "runtime.ml"
let run = Test_support.run suite
let expect = Test_support.expect
let expect_equal = Test_support.expect_equal

let build key_map combos =
  Automaton.create key_map combos

let run_events automaton events =
  let pending = ref events in
  let reads = ref 0 in
  let reader () =
    incr reads;
    match !pending with
    | [] -> failwith "runtime read past the scripted quit event"
    | event :: rest ->
        pending := rest;
        event
  in
  let path = Test_support.temporary_path "runtime_" ".out" in
  let output = open_out path in
  Runtime.run reader output automaton;
  close_out output;
  let content = Test_support.read_file path in
  Test_support.remove_if_present path;
  (content, !reads)

let () =
  run "resolve mapped keys and print all homonymous moves" (fun () ->
      let automaton =
        build [("q", "A")]
          [(["A"], "First Move"); (["A"], "Second Move")]
      in
      let output, reads =
        run_events automaton [Runtime.Key "q"; Runtime.Quit]
      in
      expect_equal
        "A\nFirst Move !!\nSecond Move !!\n"
        output
        "mapped input or homonymous recognition output was incorrect";
      expect_equal 2 reads "quit caused an additional event read");

  run "select the longest move along a common prefix" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"], "Move A");
           (["A"; "B"], "Move AB");
           (["A"; "B"; "A"], "Move ABA")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Key "b"; Runtime.Key "a";
           Runtime.Quit]
      in
      expect_equal
        "A, B, A\nMove ABA !!\n"
        output
        "the longest common-prefix move was not selected");

  run "commit a shorter move after the timeout" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"], "Move A"); (["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Timeout; Runtime.Key "b";
           Runtime.Quit]
      in
      expect_equal "A\nMove A !!\nB\n" output
        "the timeout did not commit and reset the shorter move");

  run "preserve an unrecognized partial sequence across timeout" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Timeout; Runtime.Key "b";
           Runtime.Quit]
      in
      expect_equal "A\nA, B\nMove AB !!\n" output
        "timeout reset an unrecognized partial sequence");

  run "commit a pending move before an invalid continuation" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B"); ("c", "C")]
          [(["A"], "Move A");
           (["A"; "B"], "Move AB");
           (["C"], "Move C")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Key "c"; Runtime.Quit]
      in
      expect_equal "A\nMove A !!\nC\nMove C !!\n" output
        "an invalid continuation discarded the pending move");

  run "commit a pending move on quit" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"], "Move A"); (["A"; "B"], "Move AB")]
      in
      let output, reads =
        run_events automaton [Runtime.Key "a"; Runtime.Quit]
      in
      expect_equal "A\nMove A !!\n" output
        "quit discarded the pending move";
      expect_equal 2 reads "quit caused an additional event read");

  run "retry a failed continuation from the initial state" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B"); ("c", "C")]
          [(["A"; "B"], "Move AB"); (["C"], "Move C")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Key "c"; Runtime.Quit]
      in
      expect_equal "A\nC\nMove C !!\n" output
        "failed continuation did not restart from its current token");

  run "commit a pending move on a known but unmapped key" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"], "Move A"); (["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Key "f1"; Runtime.Key "b";
           Runtime.Quit]
      in
      expect_equal "A\nMove A !!\nf1\nB\n" output
        "an unmapped key did not commit and reset the pending move");

  run "commit a pending move on an unsupported key" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"], "Move A"); (["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Unsupported_key; Runtime.Key "b";
           Runtime.Quit]
      in
      expect_equal "A\nMove A !!\nB\n" output
        "an unsupported key did not commit and reset the pending move");

  run "preserve a prefix across ignored events" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Ignored; Runtime.Key "b";
           Runtime.Quit]
      in
      expect_equal "A\nA, B\nMove AB !!\n" output
        "an ignored event reset the sequence");

  run "recognize repeated moves" (fun () ->
      let automaton =
        build [("a", "A"); ("b", "B")]
          [(["A"; "B"], "Move AB")]
      in
      let output, _ =
        run_events automaton
          [Runtime.Key "a"; Runtime.Key "b";
           Runtime.Key "a"; Runtime.Key "b"; Runtime.Quit]
      in
      expect_equal
        ("A\nA, B\nMove AB !!\n"
         ^ "A\nA, B\nMove AB !!\n")
        output
        "a repeated move was not recognized");

  run "print a mapped token that cannot start a sequence" (fun () ->
      let automaton =
        build [("x", "X"); ("a", "A")]
          [(["A"], "Move A")]
      in
      let output, _ =
        run_events automaton [Runtime.Key "x"; Runtime.Quit]
      in
      expect_equal "X\n" output
        "a detected mapped token disappeared after execution reset");

  run "print the physical identifier for an unmapped initial key" (fun () ->
      let automaton =
        build [("a", "A")] [(["A"], "Move A")]
      in
      let output, _ =
        run_events automaton [Runtime.Key "f1"; Runtime.Quit]
      in
      expect_equal "f1\n" output
        "an initial unmapped key did not use its physical identifier");

  run "flush output before reading the next event" (fun () ->
      let automaton =
        build [("a", "A")] [(["A"], "Move A")]
      in
      let path = Test_support.temporary_path "runtime_flush_" ".out" in
      let output = open_out path in
      let reads = ref 0 in
      let reader () =
        incr reads;
        if !reads = 1 then Runtime.Key "a"
        else
          begin
            expect_equal "A\nMove A !!\n" (Test_support.read_file path)
              "runtime output was not flushed before the next read";
            Runtime.Quit
          end
      in
      Runtime.run reader output automaton;
      close_out output;
      Test_support.remove_if_present path;
      expect_equal 2 !reads "flush test did not terminate at quit");

  Test_support.finish suite
