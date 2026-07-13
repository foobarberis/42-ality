open Parse

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

let contains text part =
  let text_length = String.length text in
  let part_length = String.length part in
  let rec search index =
    if index + part_length > text_length then
      false
    else if String.sub text index part_length = part then
      true
    else
      search (index + 1)
  in
  part_length = 0 || search 0

let expect_parse_error ?line ?reason parse =
  try
    let _ = parse () in
    failwith "expected Parse_error, but parsing succeeded"
  with
  | Parse_error message ->
      begin
        match line with
        | Some number ->
            let prefix = Printf.sprintf "line %d:" number in
            expect (contains message prefix)
              (Printf.sprintf "expected %S in parse error, got %S" prefix message)
        | None -> ()
      end;
      begin
        match reason with
        | Some value ->
            expect (contains message value)
              (Printf.sprintf "expected %S in parse error, got %S" value message)
        | None -> ()
      end
  | exn ->
      failwith ("expected Parse_error, got " ^ Printexc.to_string exn)

let remove_if_present path =
  if Sys.file_exists path then Sys.remove path

let with_grammar contents test =
  let path = Filename.temp_file "ft_ality_parse_" ".gmr" in
  let output = open_out path in
  try
    output_string output contents;
    close_out output;
    let result = test path in
    remove_if_present path;
    result
  with error ->
    close_out_noerr output;
    remove_if_present path;
    raise error

let parse contents =
  with_grammar contents load_automaton

let reject ?line ?reason contents =
  with_grammar contents (fun path ->
      expect_parse_error ?line ?reason (fun () -> load_automaton path))

let () =
  Printf.printf "parse.ml\n%!";

  run "parse every resource grammar" (fun () ->
      List.iter
        (fun path ->
          let grammar = load_automaton path in
          expect (grammar.Automaton.ParsingTypes.input_map <> [])
            (path ^ " has no parsed inputs");
          expect (grammar.Automaton.ParsingTypes.combos <> [])
            (path ^ " has no parsed combos"))
        [ "res/subject.gmr";
          "res/common_prefix.gmr";
          "res/overlapping_sequences.gmr";
          "res/ten_word_sentence.gmr" ]);

  run "preserve order and trim surrounding whitespace" (fun () ->
      let grammar =
        parse
          "  #input  \n\n  q  ;  Light Punch  \n down ; Down \n\n  #combos \n Light Punch , Down ; Test Move  \n"
      in
      expect_equal
        [ ("q", "Light Punch"); ("down", "Down") ]
        grammar.Automaton.ParsingTypes.input_map
        "input mappings were not trimmed or kept in order";
      expect_equal
        [ (["Light Punch"; "Down"], "Test Move") ]
        grammar.Automaton.ParsingTypes.combos
        "combos were not trimmed or kept in order");

  run "consecutive parses have no shared state" (fun () ->
      let first = parse "#input\na;A\n#combos\nA;First\n" in
      let second = parse "#input\nb;B\n#combos\nB;Second\n" in
      expect_equal [ ("a", "A") ] first.Automaton.ParsingTypes.input_map
        "first parse changed";
      expect_equal [ ("b", "B") ] second.Automaton.ParsingTypes.input_map
        "second parse reused state";
      expect_equal [ (["B"], "Second") ]
        second.Automaton.ParsingTypes.combos
        "second parse reused combo state");

  run "reject a missing file" (fun () ->
      expect_parse_error ~reason:"failed to open grammar file"
        (fun () -> load_automaton "test/fixtures/parse/does-not-exist.gmr"));

  run "reject blank and missing sections" (fun () ->
      reject ~line:1 ~reason:"expected #input" "";
      reject ~line:3 ~reason:"expected #input" "\n\n";
      reject ~line:3 ~reason:"expected #combos" "#input\na;A\n");

  run "enforce section position and order" (fun () ->
      reject ~line:1 ~reason:"first non-blank" "a;A\n#input\n#combos\n";
      reject ~line:1 ~reason:"before #combos" "#combos\n";
      reject ~line:2 ~reason:"more than once" "#input\n#input\n#combos\n";
      reject ~line:3 ~reason:"more than once" "#input\n#combos\n#combos\n";
      reject ~line:3 ~reason:"after #combos" "#input\n#combos\n#input\n";
      reject ~line:2 ~reason:"unknown section header"
        "#input\n#moves\n#combos\n";
      reject ~line:1 ~reason:"unknown section header" "#Input\n#combos\n");

  run "parse direct symbol keys" (fun () ->
      let grammar =
        parse "#input\n*;Star\n(;Open\n);Close\n!;Bang\n#combos\nStar;Move\n"
      in
      expect_equal
        [ ("*", "Star"); ("(", "Open"); (")", "Close"); ("!", "Bang") ]
        grammar.Automaton.ParsingTypes.input_map
        "printable symbol keys were not accepted");

  run "parse every supported named key category" (fun () ->
      let keys =
        [ "up"; "down"; "left"; "right";
          "space"; "tab"; "enter"; "escape"; "backspace";
          "semicolon"; "comma"; "hash";
          "f1"; "f2"; "f3"; "f4"; "f5"; "f6";
          "f7"; "f8"; "f9"; "f10"; "f11"; "f12" ]
      in
      let entries =
        List.mapi
          (fun index key -> Printf.sprintf "%s;token%d" key index)
          keys
      in
      let grammar =
        parse
          ("#input\n" ^ String.concat "\n" entries
           ^ "\n#combos\ntoken0;Move\n")
      in
      expect_equal keys
        (List.map fst grammar.Automaton.ParsingTypes.input_map)
        "a supported named key was rejected");

  run "reject reserved and unsupported input keys" (fun () ->
      reject ~line:2 ~reason:"exactly one" "#input\n;;Token\n#combos\n";
      reject ~line:2 ~reason:"unsupported input key"
        "#input\n,;Token\n#combos\n";
      reject ~line:2 ~reason:"unknown section header"
        "#input\n#;Token\n#combos\n";
      reject ~line:2 ~reason:"input key is empty"
        "#input\n ;Token\n#combos\n";
      List.iter
        (fun key ->
          reject ~line:2 ~reason:"unsupported input key"
            ("#input\n" ^ key ^ ";Token\n#combos\n"))
        [ "fn"; "pageup"; "F1"; "aa" ]);

  run "reject malformed input entries" (fun () ->
      reject ~line:2 ~reason:"exactly one" "#input\na A\n#combos\n";
      reject ~line:2 ~reason:"exactly one" "#input\na;A;extra\n#combos\n";
      reject ~line:2 ~reason:"input key is empty" "#input\n;A\n#combos\n";
      reject ~line:2 ~reason:"input token is empty" "#input\na; \n#combos\n";
      reject ~line:2 ~reason:"cannot contain ','"
        "#input\na;A,B\n#combos\n");

  run "reject malformed combo entries" (fun () ->
      reject ~line:4 ~reason:"exactly one"
        "#input\na;A\n#combos\nA Move\n";
      reject ~line:4 ~reason:"exactly one"
        "#input\na;A\n#combos\nA;Move;extra\n";
      reject ~line:4 ~reason:"sequence is empty"
        "#input\na;A\n#combos\n;Move\n";
      reject ~line:4 ~reason:"name is empty"
        "#input\na;A\n#combos\nA; \n";
      List.iter
        (fun sequence ->
          reject ~line:4 ~reason:"empty token"
            ("#input\na;A\n#combos\n" ^ sequence ^ ";Move\n"))
        [ ",A"; "A,"; "A,,A"; "A, ,A" ]);

  run "allow structurally empty sections" (fun () ->
      let both_empty = parse "#input\n#combos\n" in
      expect_equal [] both_empty.Automaton.ParsingTypes.input_map
        "empty input section was not returned";
      expect_equal [] both_empty.Automaton.ParsingTypes.combos
        "empty combo section was not returned";
      let empty_input = parse "#input\n#combos\nA;Move\n" in
      expect_equal [] empty_input.Automaton.ParsingTypes.input_map
        "empty input section was rejected";
      let empty_combos = parse "#input\na;A\n#combos\n" in
      expect_equal [] empty_combos.Automaton.ParsingTypes.combos
        "empty combo section was rejected");

  run "report physical source line numbers" (fun () ->
      reject ~line:5 ~reason:"empty token"
        "\n#input\na;A\n#combos\nA,,A;Move\n");

  let ok = !total - !failed in
  Printf.printf "SUMMARY: %d OK / %d FAIL\n%!" ok !failed;
  if !failed <> 0 then exit 1
