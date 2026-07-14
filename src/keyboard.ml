let init () =
  Sdl.init [`VIDEO];
  Sdlkey.enable_unicode true

let identifier_of_keydown event =
  match event.Sdlevent.keysym with
  | Sdlkey.KEY_UP -> Some "up"
  | Sdlkey.KEY_DOWN -> Some "down"
  | Sdlkey.KEY_LEFT -> Some "left"
  | Sdlkey.KEY_RIGHT -> Some "right"
  | Sdlkey.KEY_SPACE -> Some "space"
  | Sdlkey.KEY_TAB -> Some "tab"
  | Sdlkey.KEY_RETURN -> Some "enter"
  | Sdlkey.KEY_ESCAPE -> Some "escape"
  | Sdlkey.KEY_BACKSPACE -> Some "backspace"
  | Sdlkey.KEY_SEMICOLON -> Some "semicolon"
  | Sdlkey.KEY_COMMA -> Some "comma"
  | Sdlkey.KEY_HASH -> Some "hash"
  | Sdlkey.KEY_F1 -> Some "f1"
  | Sdlkey.KEY_F2 -> Some "f2"
  | Sdlkey.KEY_F3 -> Some "f3"
  | Sdlkey.KEY_F4 -> Some "f4"
  | Sdlkey.KEY_F5 -> Some "f5"
  | Sdlkey.KEY_F6 -> Some "f6"
  | Sdlkey.KEY_F7 -> Some "f7"
  | Sdlkey.KEY_F8 -> Some "f8"
  | Sdlkey.KEY_F9 -> Some "f9"
  | Sdlkey.KEY_F10 -> Some "f10"
  | Sdlkey.KEY_F11 -> Some "f11"
  | Sdlkey.KEY_F12 -> Some "f12"
  | _ ->
      let code = int_of_char event.Sdlevent.keycode in
      if code >= 33 && code <= 126 then
        Some (String.make 1 event.Sdlevent.keycode)
      else
        None

let wait_keydown () =
  match Sdlevent.wait_event () with
  | Sdlevent.KEYDOWN event -> identifier_of_keydown event
  | _ -> None
