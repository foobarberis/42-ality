let suite = Test_support.start "keyboard.ml"
let run = Test_support.run suite
let expect_equal = Test_support.expect_equal

let with_pending characters action =
  Keyboard.pending_character := None;
  Keyboard.pending_characters := characters;
  let result = action () in
  Keyboard.pending_character := None;
  Keyboard.pending_characters := [];
  result

let () =
  run "classify terminal printable keys and aliases" (fun () ->
      expect_equal (Runtime.Key "q")
        (Keyboard.event_of_character 'q')
        "terminal letter was not classified";
      expect_equal (Runtime.Key "!")
        (Keyboard.event_of_character '!')
        "terminal shifted symbol was not classified";
      expect_equal (Runtime.Key "space")
        (Keyboard.event_of_character ' ')
        "terminal space alias was incorrect";
      expect_equal (Runtime.Key "semicolon")
        (Keyboard.event_of_character ';')
        "terminal semicolon alias was incorrect";
      expect_equal (Runtime.Key "comma")
        (Keyboard.event_of_character ',')
        "terminal comma alias was incorrect";
      expect_equal (Runtime.Key "hash")
        (Keyboard.event_of_character '#')
        "terminal hash alias was incorrect");

  run "classify terminal control keys" (fun () ->
      expect_equal (Runtime.Key "tab")
        (Keyboard.event_of_character '\t')
        "terminal tab was not classified";
      expect_equal (Runtime.Key "enter")
        (Keyboard.event_of_character '\n')
        "terminal enter was not classified";
      expect_equal (Runtime.Key "escape")
        (with_pending ['x'] (fun () -> Keyboard.event_of_character '\027'))
        "terminal escape was not classified";
      expect_equal (Runtime.Key "backspace")
        (Keyboard.event_of_character '\127')
        "terminal backspace was not classified";
      expect_equal Runtime.Quit
        (Keyboard.event_of_character '\004')
        "terminal end-of-input did not quit";
      expect_equal Runtime.Unsupported_key
        (Keyboard.event_of_character '\001')
        "unsupported terminal control was not classified");

  run "decode terminal arrows" (fun () ->
      expect_equal (Runtime.Key "up")
        (with_pending ['['; 'A']
           (fun () -> Keyboard.event_of_character '\027'))
        "CSI up arrow was not decoded";
      expect_equal (Runtime.Key "left")
        (with_pending ['['; 'D']
           (fun () -> Keyboard.event_of_character '\027'))
        "CSI left arrow was not decoded";
      expect_equal (Runtime.Key "down")
        (with_pending ['O'; 'B']
           (fun () -> Keyboard.event_of_character '\027'))
        "SS3 down arrow was not decoded";
      expect_equal (Runtime.Key "right")
        (with_pending ['O'; 'C']
           (fun () -> Keyboard.event_of_character '\027'))
        "SS3 right arrow was not decoded");

  run "reject unsupported escape sequences" (fun () ->
      expect_equal Runtime.Unsupported_key
        (with_pending ['O'; 'P']
           (fun () -> Keyboard.event_of_character '\027'))
        "SS3 function-key sequence was accepted";
      expect_equal Runtime.Unsupported_key
        (with_pending ['['; '1'; '1'; '~']
           (fun () -> Keyboard.event_of_character '\027'))
        "CSI function-key sequence was accepted");

  Test_support.finish suite
