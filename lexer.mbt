///|
priv struct Token {
  text : String
  offset : Int32
  quoted : Bool
}

///|
fn lex(source : String) -> Array[Token] raise CddlError {
  if source.length() > 65536 {
    raise Limit("schema exceeds 65536 UTF-16 units")
  }
  let out : Array[Token] = []
  let mut i = 0
  while i < source.length() {
    let c = source[i]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      i = i + 1
      continue
    }
    if c == ';' {
      while i < source.length() && source[i] != '\n' {
        i = i + 1
      }
      continue
    }
    let start = i
    if c == '"' {
      i = i + 1
      let mut closed = false
      while i < source.length() {
        if source[i] == '\\' {
          i = i + 2
          continue
        }
        if source[i] == '"' {
          i = i + 1
          closed = true
          break
        }
        i = i + 1
      }
      if !closed {
        raise Syntax(start, "unterminated text literal")
      }
      out.push({
        text: source[start:i].to_owned(),
        offset: start,
        quoted: true,
      })
    } else if (c >= '0' && c <= '9') ||
      (
        c == '-' &&
        i + 1 < source.length() &&
        source[i + 1] >= '0' &&
        source[i + 1] <= '9'
      ) {
      i = i + 1
      while i < source.length() && source[i] >= '0' && source[i] <= '9' {
        i = i + 1
      }
      out.push({
        text: source[start:i].to_owned(),
        offset: start,
        quoted: false,
      })
    } else if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      c == '_' ||
      c == '$' {
      i = i + 1
      while i < source.length() {
        let d = source[i]
        if (d >= 'a' && d <= 'z') ||
          (d >= 'A' && d <= 'Z') ||
          (d >= '0' && d <= '9') ||
          d == '_' ||
          d == '-' ||
          d == '$' {
          i = i + 1
        } else {
          break
        }
      }
      out.push({
        text: source[start:i].to_owned(),
        offset: start,
        quoted: false,
      })
    } else {
      i = i + 1
      if c == '.' && i < source.length() && source[i] == '.' {
        i = i + 1
        if i < source.length() && source[i] == '.' {
          i = i + 1
        }
      } else if (c == '=' && i < source.length() && source[i] == '>') ||
        (c == '/' && i < source.length() && source[i] == '/') {
        i = i + 1
      }
      out.push({
        text: source[start:i].to_owned(),
        offset: start,
        quoted: false,
      })
    }
    if out.length() > 8192 {
      raise Limit("schema exceeds 8192 tokens")
    }
  }
  out.push({ text: "<eof>", offset: source.length(), quoted: false, })
  out
}
