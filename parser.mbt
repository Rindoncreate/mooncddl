///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int32
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::take(self : Parser) -> Token {
  let token = self.peek()
  if token.text != "<eof>" {
    self.index = self.index + 1
  }
  token
}

///|
fn Parser::accept(self : Parser, text : String) -> Bool {
  if self.peek().text == text {
    ignore(self.take())
    true
  } else {
    false
  }
}

///|
fn Parser::expect(self : Parser, text : String) -> Unit raise CddlError {
  if !self.accept(text) {
    raise Syntax(self.peek().offset, "expected " + text)
  }
}

///|
fn integer(token : Token) -> Int64 raise CddlError {
  @string.parse_int64(token.text) catch {
    _ => raise Syntax(token.offset, "expected a signed 64-bit decimal integer")
  }
}

///|
fn is_integer(token : Token) -> Bool {
  let text = token.text
  if text.length() == 0 {
    return false
  }
  let start = if text[0] == '-' { 1 } else { 0 }
  start < text.length() && text[start:].iter().all(c => c >= '0' && c <= '9')
}

///|
fn is_name(token : Token) -> Bool {
  if token.quoted || token.text.length() == 0 {
    return false
  }
  let c = token.text[0]
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn primitive(name : String) -> Bool {
  [
    "any", "uint", "nint", "int", "float", "bool", "tstr", "text", "bstr", "bytes",
    "nil", "null",
  ].contains(name)
}

///|
/// Compile once. All rules, including unreachable rules, are checked.
pub fn compile(source : String, root~ : String = "") -> Schema raise CddlError {
  let p = Parser::{ tokens: lex(source), index: 0, }
  let rules : Map[String, Node] = Map([])
  let mut first = ""
  while p.peek().text != "<eof>" {
    let name = p.take()
    if !is_name(name) ||
      primitive(name.text) ||
      name.text == "true" ||
      name.text == "false" {
      raise Syntax(name.offset, "expected a non-predefined rule name")
    }
    if rules.contains(name.text) {
      raise InvalidSchema("duplicate rule: " + name.text)
    }
    p.expect("=")
    let node = p.parse_type(0)
    rules.set(name.text, node)
    if first == "" {
      first = name.text
    }
    if rules.length() > 256 {
      raise Limit("at most 256 rules")
    }
  }
  let root = if root == "" { first } else { root }
  if !rules.contains(root) {
    raise InvalidSchema("missing root rule: " + root)
  }
  for _, node in rules {
    check_refs(node, rules, 0)
  }
  // Alias cycles cannot consume input and are rejected before validation.
  for name, _ in rules {
    check_alias(name, rules, [], 0)
  }
  { rules, root, }
}

///|
fn Parser::parse_type(self : Parser, depth : Int32) -> Node raise CddlError {
  if depth > 64 {
    raise Limit("schema nesting exceeds 64")
  }
  let choices = [self.parse_term(depth + 1)]
  while self.accept("/") {
    choices.push(self.parse_term(depth + 1))
  }
  if choices.length() == 1 {
    choices[0]
  } else {
    Choice(choices)
  }
}

///|
fn Parser::parse_term(self : Parser, depth : Int32) -> Node raise CddlError {
  let mut node = self.parse_atom(depth)
  if self.peek().text == ".." || self.peek().text == "..." {
    let inclusive = self.take().text == ".."
    let end = integer(self.take())
    guard node is Literal(Integer(start)) else {
      raise Syntax(self.peek().offset, "range start must be an integer")
    }
    if start > end || (start == end && !inclusive) {
      raise InvalidSchema("empty or reversed range")
    }
    node = Range(start, end, inclusive)
  }
  if self.accept(".") {
    let operator = self.take()
    if operator.text != "size" {
      raise Unsupported(operator.offset, "only .size is supported")
    }
    let controller = self.parse_atom(depth + 1)
    let (lower, upper) = match controller {
      Literal(Integer(n)) => (n, n)
      Range(a, b, inclusive) => (a, if inclusive { b } else { b - 1 })
      _ =>
        raise Unsupported(
          operator.offset,
          ".size controller must be an integer or parenthesized integer range",
        )
    }
    if lower < 0 || upper < lower {
      raise InvalidSchema("invalid .size interval")
    }
    node = Sized(node, lower, upper)
  }
  node
}

///|
fn Parser::parse_atom(self : Parser, depth : Int32) -> Node raise CddlError {
  if depth > 64 {
    raise Limit("schema nesting exceeds 64")
  }
  let token = self.take()
  if token.quoted {
    return match
      (@json.parse(token.text) catch {
        _ => raise Syntax(token.offset, "invalid JSON-style string literal")
      }) {
      String(value) => Literal(Text(value))
      _ => raise Syntax(token.offset, "expected text literal")
    }
  }
  if is_integer(token) {
    return Literal(Integer(integer(token)))
  }
  match token.text {
    "[" => Sequence(self.parse_entries("]", false, depth + 1))
    "{" => Record(self.parse_entries("}", true, depth + 1))
    "(" => {
      let node = self.parse_type(depth + 1)
      self.expect(")")
      node
    }
    "true" => Literal(Boolean(true))
    "false" => Literal(Boolean(false))
    "nil" | "null" => Literal(Null)
    "#" => {
      self.expect("6")
      self.expect(".")
      let tag = integer(self.take())
      if tag < 0 {
        raise InvalidSchema("tag must be nonnegative")
      }
      self.expect("(")
      let node = self.parse_type(depth + 1)
      self.expect(")")
      Tag(tag, node)
    }
    "<eof>" => raise Syntax(token.offset, "unexpected end of schema")
    _ =>
      if primitive(token.text) {
        Primitive(token.text)
      } else if is_name(token) {
        Ref(token.text)
      } else {
        raise Unsupported(token.offset, "unsupported token: " + token.text)
      }
  }
}

///|
fn Parser::parse_entries(
  self : Parser,
  end : String,
  is_map : Bool,
  depth : Int32,
) -> Array[Entry] raise CddlError {
  let entries : Array[Entry] = []
  while !self.accept(end) {
    let mut minimum = 1
    let mut maximum = 1
    if self.accept("?") {
      minimum = 0
    } else if self.accept("+") {
      maximum = 1000000
    } else if self.accept("*") {
      minimum = 0
      maximum = if is_integer(self.peek()) {
        occurrence(self.take())
      } else {
        1000000
      }
    } else if is_integer(self.peek()) && self.tokens[self.index + 1].text == "*" {
      minimum = occurrence(self.take())
      self.expect("*")
      maximum = if is_integer(self.peek()) {
        occurrence(self.take())
      } else {
        1000000
      }
    }
    if maximum < minimum {
      raise InvalidSchema("reversed occurrence limits")
    }
    let mut key : Node? = None
    let node = if is_map &&
      (self.peek().quoted || is_name(self.peek()) || is_integer(self.peek())) &&
      self.tokens[self.index + 1].text == ":" {
      let token = self.take()
      self.expect(":")
      key = Some(
        if token.quoted {
          match
            (@json.parse(token.text) catch {
              _ => raise Syntax(token.offset, "invalid key")
            }) {
            String(s) => Literal(Text(s))
            _ => raise Syntax(token.offset, "invalid key")
          }
        } else if is_integer(token) {
          Literal(Integer(integer(token)))
        } else {
          Literal(Text(token.text))
        },
      )
      self.parse_type(depth + 1)
    } else {
      let first = self.parse_type(depth + 1)
      if is_map {
        self.expect("=>")
        key = Some(first)
        self.parse_type(depth + 1)
      } else {
        first
      }
    }
    entries.push({ key, value: node, minimum, maximum, })
    if entries.length() > 256 {
      raise Limit("at most 256 entries per collection")
    }
    if self.accept(",") {
      continue
    }
    if self.peek().text == end {
      continue
    }
    // RFC permits omitted commas, but unsupported group operators must fail.
    if self.peek().text == "//" || self.peek().text == "<eof>" {
      raise Unsupported(
        self.peek().offset,
        "group choices and unterminated collections are not supported",
      )
    }
  }
  entries
}

///|
fn occurrence(token : Token) -> Int32 raise CddlError {
  let n = integer(token)
  if n < 0 || n > 1000000 {
    raise Limit("occurrence must be within 0..1000000")
  }
  n.to_int()
}

///|
fn check_refs(
  node : Node,
  rules : Map[String, Node],
  depth : Int32,
) -> Unit raise CddlError {
  if depth > 64 {
    raise Limit("schema nesting exceeds 64")
  }
  match node {
    Ref(name) =>
      if !rules.contains(name) {
        raise InvalidSchema("undefined rule: " + name)
      }
    Choice(nodes) =>
      for child in nodes {
        check_refs(child, rules, depth + 1)
      }
    Sized(child, _, _) | Tag(_, child) => check_refs(child, rules, depth + 1)
    Sequence(entries) | Record(entries) =>
      for entry in entries {
        if entry.key is Some(key) {
          check_refs(key, rules, depth + 1)
        }
        check_refs(entry.value, rules, depth + 1)
      }
    _ => ()
  }
}

///|
fn check_alias(
  name : String,
  rules : Map[String, Node],
  seen : Array[String],
  depth : Int32,
) -> Unit raise CddlError {
  if seen.contains(name) {
    raise InvalidSchema("non-consuming reference cycle: " + name)
  }
  if depth > 64 {
    raise Limit("alias chain exceeds 64")
  }
  let next = seen.copy()
  next.push(name)
  fn visit(node : Node) -> Unit raise CddlError {
    match node {
      Ref(other) => check_alias(other, rules, next, depth + 1)
      Choice(nodes) =>
        for child in nodes {
          visit(child)
        }
      Sized(child, _, _) => visit(child)
      _ => () // Collections and tags consume a data node before recursion.
    }
  }
  if rules.get(name) is Some(node) {
    visit(node)
  }
}
