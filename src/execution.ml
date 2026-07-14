type state = {
  automaton_state : string;
  sequence : string list;
}

type result = {
  next : state;
  recognized : string list;
}

let initial automaton =
  {
    automaton_state = automaton.Automaton.AutomataTypes.initial;
    sequence = [];
  }

let reset automaton =
  initial automaton

let advance automaton state token =
  match
    Automaton.Automata.step automaton state.automaton_state token
  with
  | None -> None
  | Some automaton_state ->
      let next =
        {
          automaton_state;
          sequence = state.sequence @ [token];
        }
      in
      Some
        {
          next;
          recognized =
            Automaton.Automata.get_final_combos automaton automaton_state;
        }

let handle_token automaton state token =
  match advance automaton state token with
  | Some result -> result
  | None ->
      begin
        match advance automaton (initial automaton) token with
        | Some result -> result
        | None ->
            {
              next = initial automaton;
              recognized = [];
            }
      end
