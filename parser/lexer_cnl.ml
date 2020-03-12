(* ocamlfind ocamlc -c -package sedlex my_file.ml *)

(*

Lexical structure of Colada language in Sedlex. 

The longest match rule holds (following sedlex).

  PERIOD is used to demarcate statements (and sections, etc.)
  Most parsing can be done on a statement by statement basis.
  (That is, to parse a statement, it is never necessary to look further ahead.)

  Delimiters, COMMA, and SEMI cannot be combined into larger lexemes. 
  Delimiters must alway occur in properly nested matching pairs. 

  The only characters that may appear in identifiers are A-Z a-z 0-9 ' _ PERIOD
  The initial character must be alphabetic [a-zA-Z].
  The final character must not be a PERIOD.

  According to the internal structure of the identifier, the identifier is
  classified as
  a variable, an atomic identifier, a hierarchical identifier, or a word. 
  A word is case insensitive, but other types of identifiers are case sensitive. 
  There are no keywords, but many words (if, then, else, section, etc.)
  have special meaning in particular
  contexts. 

  A field accessor begins with a PERIOD and otherwise has the same structure
  as a hierarchical identifier. 

  A control sequence is sequence of characters starting with backslash \
  and continuing with alphabetic characters [a-z][A-Z].  
  Control sequences are case sensitive.

  A second form of control sequence consists of a single backslash followed
  by a single character. 
  The second character cannot be alphabetic, a delimiter, or (most) separators. 

  

 *)

(* Singularization Rules (applied in order)
   * Do not change a word not ending in s.
   * Do not change a word with at most 4 characters. 
   * Do not change a word if it would result in a word of 2 characters or fewer.
   * Do not change a word ending in -ss or -ous. 
   * C + oes -> C + o
   * C + ies -> C + y
   * Drop the final s in words ending in ize/ise + s
   * Drop the final es in words ending in ch/ss/sh/x/z + es 
   * Otherwise, drop the final s. 

   The rules are not intended to give the correct singularization in all cases.
   They are intended to capture most singular forms in regular use in mathematics,
   while not creating false singulars that would collide with another word
   in common use. 

   Synonyms may be used wherever these rules fail.
 *)

let singularize  =
  let rexp = Str.regexp in 
  let smatch r s = Str.string_match r s 0 in
  let group  = Str.matched_group in 
  let reg_ss = rexp ".*ss$" in 
  let reg_ous = rexp ".*ous$" in 
  let reg_oes = rexp "\\(.*[^aeiou]o\\)es$" in 
  let reg_ies = rexp "\\(.*[^aeiou]\\)ies$" in 
(*  let reg_ves = rexp "\\(.*\\)ves$" in too many exceptions *)
  let reg_ize = rexp "\\(.*ize\\)s$" in 
  let reg_ise = rexp "\\(.*ise\\)s$" in 
  let reg_xes = rexp "\\(.*\\)\\(ch\\|ss\\|sh\\|x\\|z\\)es$" in
  let reg_s = rexp "\\(.*\\)s$" in 
  let i s = s in
  let mm = [(smatch reg_ss,i);
            (smatch reg_ous,i);
            (smatch reg_oes,fun s -> group 1 s);
            (smatch reg_ies,fun s -> group 1 s^"y");
(*            (smatch reg_ves,fun s -> group 1 s^ "f"); *)
            (smatch reg_ize,fun s -> group 1 s);
            (smatch reg_ise,fun s -> group 1 s);
            (smatch reg_xes,fun s -> group 1 s ^ group 2 s);
            (smatch reg_s,fun s -> group 1 s)
    ] in 
  fun s ->
        let s = String.lowercase_ascii s in 
        if String.length s <= 4 || not(s.[String.length s -1] = 's') then s 
        else  
          let s' = match List.find_opt (fun (m,_) -> m s) mm with
          | None -> failwith "singularize: matching pattern expected"
          | Some (_,r) -> r s in 
          if String.length s' <= 2 then s else s';;

(*
let _ = List.map (fun t -> (print_endline (t ^" "^singularize t)))
[
"has";"rat";"does";"obsess";"flux";"busses";"industrious";"pianos";"heroes";"tries";"plays";"elves";"twelves";"foxes";"lives";"breeches";"rushes";"fluxes";"lashes";
"dazes";"series";"porous";"realizes";"actualizes";"incises";"utilises";"tractrixes";"ruins";"collides";"solves";"curves";"carves";"motives";"motifs";"bodies";"measures";"cases";"courses";"transverses"
];;
 *)

(* module Sedlexing = Lexbuffer *)

(*
exception LexError of (string * int * int * string * string)

let raise_lex (p: Lexing.position) tok msg =                
  let open Lexing in
  let line = p.pos_lnum in
  let col = p.pos_cnum - p.pos_bol in
  raise @@ LexError (p.pos_fname, line, col, tok, msg)
 *)

(* type *)

type token = 
  | STRING of string
  | CONTROLSEQ of string
  | DECIMAL of string
  | INTEGER of string
  | SYMBOL of string
  | SYMBOL_QED
  | L_PAREN
  | R_PAREN
  | L_BRACK
  | R_BRACK
  | L_BRACE
  | R_BRACE
  | MAPSTO
  | PERIOD
  | MID
  | TMID
  | COMMA
  | SEMI
  | COLON
  | ASSIGN
  | ARROW
  | BLANK
  | ALT
  | APPLYSUB
  | SLASH
  | SLASHDASH
  | COERCION
  | LAMBDA
  | PITY
  | QUANTIFIER of string
  | VAR of string
  | METAVAR of string
  | WORD of string*string
  | ATOMIC_IDENTIFIER of string
  | HIERARCHICAL_IDENTIFIER of string
  | FIELD_ACCESSOR of string
  | EOF
  | UNKNOWN of string 
[@@deriving show]

type node =
{
 pos : Lexing.position*Lexing.position; (* start and end *)
 tok : token
}

let empty_pos = 
  let open Lexing in 
  { pos_fname = ""; pos_lnum = 0; pos_bol = 0; pos_cnum = 0 }

let pp_node f n = 
  pp_token f n.tok

let tok n = n.tok

(* -- Lexical structure -- *)

let digit =
  [%sedlex.regexp? '0'..'9']
let number =
  [%sedlex.regexp? Plus(digit)]
let integer = 
  [%sedlex.regexp? ('+' | '-'), number]
let decimal =
  [%sedlex.regexp? Opt('+' | '-'), number , '.', number]

let eol =   [%sedlex.regexp?  '\n']

let comment = [%sedlex.regexp? '%', Star(Compl(eol))]
  
let white =
  [%sedlex.regexp? ' ' | '\r' | '\n' | '\t' | '\012' ] 

let string_escape = [%sedlex.regexp?
'\\' , ('\\' | '"' | "'" | "n" | "t" )]

let string_char = [%sedlex.regexp? Compl('\\' | '\"')]

let string_item = [%sedlex.regexp? string_char | string_escape  ]

let string = [%sedlex.regexp? '"', Star(string_item), '"']

let alphabet = [%sedlex.regexp? 'a'..'z' | 'A'..'Z']

let alphanum_nonblank = [%sedlex.regexp? alphabet | digit | "'"]

let alphanum = [%sedlex.regexp? alphabet | digit | '_' | "'"]
             
let controlseq = [%sedlex.regexp? '\\', Plus(alphabet)]

let varlong = [%sedlex.regexp? alphabet, '_', '_', Star(alphanum)] (* mangling *)

(* 
   initial blank is reserved for internal use 
*)
let identifier = [%sedlex.regexp? alphanum_nonblank, Star(alphanum) ]          

let hierarchical_identifier = [%sedlex.regexp? identifier, Plus('.', identifier) ]  

let field_accessor = [%sedlex.regexp? '.', identifier] (* was Plus('.',identifier) *)

let tex2cnl_error = [%sedlex.regexp? "[TeX2CnlError", Star(white), string, Star(white), "]"]

let tex2cnl_warning = [%sedlex.regexp? "[TeX2CnlWarning", Star(white), string, Star(white), "]"]


let lparen = [%sedlex.regexp? '(' ]  
let rparen = [%sedlex.regexp? ')' ]
let lbrack = [%sedlex.regexp? '[' ]  
let rbrack = [%sedlex.regexp? ']' ]
let lbrace = [%sedlex.regexp? '{' ]
let rbrace = [%sedlex.regexp? '}' ]
let comma = [%sedlex.regexp? ',']
let semi = [%sedlex.regexp? ';']           

(* symbol excludes '\' *)
          
let symbol = [%sedlex.regexp? '*' | '+' | '^' | '=' | '<' | '>' | '/' | '!' | 
              '@' | '#' | '$' | '&' | '_' | '-' | '|' | ':' | "'" | '.' |
              '?' | '~' | '`'] 

let symbolseq = [%sedlex.regexp? Plus(symbol)]

let controllable = [%sedlex.regexp? '.' | ',' | ':' | ';' | '|' | '\\' ]

let controlchar = [%sedlex.regexp? '\\', (symbol | controllable) ]

let controlkey s = match s with
| "\\qed" -> SYMBOL_QED
| "\\mid" -> MID
| "\\tmid" -> TMID
| "\\alt" -> ALT 
| "\\sub" -> APPLYSUB
| "\\^" -> COERCION
| "\\to" -> ARROW
| "\\mapsto" -> MAPSTO
| "\\blank" -> BLANK
| "\\\\" -> LAMBDA
| "\\lam" -> LAMBDA
| "\\lambder" -> LAMBDA
| "\\Pity" -> PITY
| "\\forall" -> QUANTIFIER s
| "\\exists" -> QUANTIFIER s
| "\\existsunique" -> QUANTIFIER s
| _ -> CONTROLSEQ s;;

let symbolkey s = match s with
  | "." -> PERIOD
  | ":" -> COLON
  | ":=" -> ASSIGN
  | "->" -> ARROW
  | "|->" -> MAPSTO
  | "|" -> ALT
  | "/" -> SLASH
  | "/-" -> SLASHDASH
  | "_" -> BLANK
  | _ -> SYMBOL s


(* We avoid lookahead by doing a post-tokenization regexp test. *)

let var = [%sedlex.regexp? alphabet, Star(digit | "'" | "_")]
let word = [%sedlex.regexp? Plus(alphabet) ]

let identkey = 
  let is_var s = 
    Str.string_match (Str.regexp "[a-zA-Z][0-9'_]*$") s 0 in
  let is_word s = 
    Str.string_match (Str.regexp "[a-zA-Z]+$") s 0 in
  fun s -> 
        if (s = "_") then BLANK
        else if is_var s then VAR s
        else if is_word s then WORD (s,singularize s)
        else ATOMIC_IDENTIFIER s
           
(* open Parser_cnl *)

let lexeme = Sedlexing.lexeme

let implode l = String.init (List.length l) (List.nth l)

let string_of_ints js =
 let cs =  List.map (fun j ->  (Uchar.to_char j)) (Array.to_list js) in
  implode cs;;

let string_lexeme buf = string_of_ints(lexeme buf)

let remove_period s = 
  String.concat "" (String.split_on_char '.' s)

let lp = Sedlexing.lexing_positions 

let mk f buf = { pos = lp buf; tok = f(string_lexeme buf) }

let c tok = (fun _ -> tok)

(* 
  The order matters here.  The first match is applied.

  Note the folowing important particular orderings:
  * (+/-) DECIMAL - INTEGER - symbolseq 
  * (periods) field_accessor - symbolseq (other periods are internal to a lexeme)
  * varlong - word - atomic_identifier (after parsing as atomic)

  Some words should actually be treated as 
  case sensitive atomic_identifiers (such as sin, cos, tan).
  This is left to the parser. 
 *)

let rec lex_node buf =
  match%sedlex buf with
  | Plus(white) -> (lex_node buf)
  | tex2cnl_error -> (print_endline(string_lexeme buf); lex_node buf)
  | tex2cnl_warning -> (print_endline(string_lexeme buf); lex_node buf)
(*  | eol -> (Sedlexing.new_line buf; lex_node buf) *)
  | comment -> (lex_node buf)
    | string -> mk (fun t -> STRING t) buf 
    | controlseq -> mk controlkey buf
    | controlchar -> mk controlkey buf
    | decimal -> mk (fun t -> DECIMAL t) buf
    | integer -> mk (fun t -> INTEGER t) buf 
    | number -> mk (fun t -> INTEGER t) buf
    | rparen -> mk (c R_PAREN) buf
    | lparen -> mk (c L_PAREN) buf
    | lbrack -> mk (c L_BRACK) buf
    | rbrack -> mk (c R_BRACK) buf
    | lbrace -> mk (c L_BRACE) buf
    | rbrace -> mk (c R_BRACE) buf
    | comma -> mk (c COMMA) buf
    | semi -> mk (c SEMI) buf 
    | field_accessor -> mk (fun t -> FIELD_ACCESSOR (remove_period t)) buf
    | hierarchical_identifier -> mk (fun t -> HIERARCHICAL_IDENTIFIER t) buf
    | varlong -> mk (fun t -> VAR t) buf
    | symbolseq -> mk symbolkey buf
    | identifier -> mk identkey buf
    | eof -> mk (c EOF ) buf
    | any -> mk (fun t -> UNKNOWN t) buf
    | _  -> failwith (string_lexeme buf)

(* testing *)

let lex_token_to_string = function
  | STRING s -> s ^ " (STRING)"
  | CONTROLSEQ s -> s ^ " (CONTROL)"
  | DECIMAL s -> s ^ " (DECIMAL)"
  | INTEGER s -> s ^ " (INTEGER)"
  | SYMBOL s -> s ^ " (SYMBOL)"
  | SYMBOL_QED -> "(QED)"
  | L_PAREN -> "(L_PAREN)"
  | R_PAREN -> "(R_PAREN)"
  | L_BRACK -> "(L_BRACK)"
  | R_BRACK -> "(R_BRACK)"
  | L_BRACE -> "(L_BRACE)"
  | R_BRACE -> "(R_BRACE)"
  | MAPSTO -> "(MAPSTO)"
  | PERIOD -> "(PERIOD)"
  | MID -> "(MID)"
  | TMID -> "(TMID)"
  | COMMA -> "(COMMA)"
  | SEMI -> "(SEMI)"
  | COLON -> "(COLON)"
  | ASSIGN -> "(ASSIGN)"
  | ARROW -> "(ARROW)"
  | BLANK -> "(BLANK)"
  | ALT -> "(ALT)"
  | APPLYSUB -> "(APPLYSUB)"
  | SLASH -> "(SLASH)"
  | SLASHDASH -> "(SLASHDASH)"
  | COERCION -> "(COERCION)"
  | LAMBDA -> "(LAMBDA)"
  | PITY -> "(PITY)"
  | QUANTIFIER s -> s ^ " (QUANTIFIER)"
  | VAR s -> s ^ " (VAR)"
  | METAVAR s -> s ^ " (METAVAR)"
  | WORD (s,_) -> s ^ " (WORD)"
  | ATOMIC_IDENTIFIER s -> s ^ " (ATOMIC)"
  | HIERARCHICAL_IDENTIFIER s -> s ^ " (HIERARCHICAL)"
  | FIELD_ACCESSOR s -> s ^ " (FIELD)"
  | EOF -> "(EOF)"
  | UNKNOWN s -> s ^ " ?"

let lex_token_to_string_brief = 
  function 
  | STRING s -> "\""^s^"\""
  | CONTROLSEQ s -> "\\"^s
  | DECIMAL s -> "D@"^s 
  | INTEGER s -> "I@"^s 
  | SYMBOL s -> "S@"^s 
  | SYMBOL_QED -> "(QED)"
  | L_PAREN -> "@("
  | R_PAREN -> "@)"
  | L_BRACK -> "["
  | R_BRACK -> "]"
  | L_BRACE -> "{"
  | R_BRACE -> "}"
  | MAPSTO -> "->"
  | PERIOD -> "."
  | MID -> "|"
  | TMID -> "//"
  | COMMA -> ","
  | SEMI -> ";"
  | COLON -> ":"
  | ASSIGN -> ":="
  | ARROW -> "->"
  | BLANK -> "_"
  | ALT -> "|"
  | APPLYSUB -> "_"
  | SLASH -> "/"
  | SLASHDASH -> "/-"
  | COERCION -> "^|"
  | LAMBDA -> ".\\"
  | PITY -> "PI"
  | QUANTIFIER s -> "Q@"^s 
  | VAR s -> "V@"^s 
  | METAVAR s -> "?"^s 
  | WORD (s,_) -> "W@"^s 
  | ATOMIC_IDENTIFIER s -> "A@"^s 
  | HIERARCHICAL_IDENTIFIER s -> "H@"^s 
  | FIELD_ACCESSOR s -> "F@"^s 
  | EOF -> "(EOF)"
  | UNKNOWN s -> s ^ " ?"


let token_to_string_plain = 
function
| STRING s ->  "\""^s^"\""
| CONTROLSEQ s -> "\\"^s
| DECIMAL s -> s
| INTEGER s ->  s
| SYMBOL s -> s
| SYMBOL_QED -> "[QED]"
| L_PAREN -> "("
| R_PAREN -> ")"
| L_BRACE -> "{"
| R_BRACE -> "}"
| MAPSTO -> "|->"
| PERIOD -> "."
| MID -> "|"
| TMID -> "//"
| COMMA -> ","
| SEMI -> ";"
| COLON -> ":"
| ASSIGN -> ":="
| ARROW -> "->"
| BLANK -> "_"
| ALT -> "|"
| APPLYSUB -> "_"
| SLASH -> "/"
| SLASHDASH -> "/-"
| COERCION -> "^"
| LAMBDA -> "\\"
| PITY -> "[PI]"
| QUANTIFIER s -> s
| ATOMIC_IDENTIFIER s -> s
| FIELD_ACCESSOR s -> s
| EOF -> "[EOF]"
| UNKNOWN s -> s^"?"
| _ -> failwith "token_to_string: not found"



let rec lex_nodes acc buf = 
  let t = lex_node buf in 
  if (tok t = EOF) then List.rev (acc) 
  else lex_nodes (t:: acc) buf

(* N.B. pos_lnum must be positive in Sedlexing or it doesn't get updated *)

let lex_string name s : node list = 
  let buf = Sedlexing.Latin1.from_string s in 
  let _ = Sedlexing.set_filename buf name in 
  let _ = Sedlexing.set_position buf { Lexing.pos_fname = name; Lexing.pos_lnum = 1; Lexing.pos_bol = 0; Lexing.pos_cnum = 0 } in
  lex_nodes [] buf;;

let string_pos (p : Lexing.position) =
  "file="^p.pos_fname ^ 
    " line=" ^string_of_int p.pos_lnum^
      " col="^string_of_int (p.pos_cnum-p.pos_bol)

(* printing *)

let rec print_nodes = function
  | [] -> ()
  | t :: ts -> 
      (print_string ("NODE:"^string_pos (fst(t.pos))^" ");
       print_endline(lex_token_to_string t.tok) ; print_nodes ts)

let string_of_toks ts = 
  let ss = List.map (fun t -> lex_token_to_string_brief t) ts in 
  String.concat " " ss;;

let string_of_toks_plain ts = 
  let ss = List.map (fun t -> lex_token_to_string_brief t) ts in 
  String.concat " " ss;;

let rec print_tok = function
  | [] -> ()
  | t :: ts -> 
      print_string(lex_token_to_string t ^ " ") ; print_tok ts

let print_nodes_brief ns = 
  print_endline (string_of_toks (List.map (fun n -> n.tok) ns))

let test_lex_string() = print_nodes (lex_string "lexer_cnl.ml" "A B C hello\\alpha33[1]there !ready! \\begin \\\\ \n Riemann-Hilbert %comment \n\n more #4 # 5  $ _id ))))))");;
              


              
(* testing stuff *)

