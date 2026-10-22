///|
priv struct Context {
  rules : Map[String, Node]
  root : String
  mut remaining : Int32
  mut stack : Int32
  mut deepest : Int32
  mut diagnostic : Diagnostic
}

///|
fn Context::step(self : Context, depth : Int32) -> Unit raise CddlError {
  if depth > 64 {
    raise Limit("validation nesting exceeds 64")
  }
  self.remaining = self.remaining - 1
  if self.remaining < 0 {
    raise Limit("validation work budget exhausted")
  }
}

///|
fn Context::enter(self : Context) -> Unit raise CddlError {
  self.stack = self.stack + 1
  if self.stack > 256 {
    raise Limit("validation call stack exceeds 256 frames")
  }
}

///|
fn Context::reject(self : Context, path : String, message : String) -> Bool {
  if path.length() > self.deepest || self.deepest == 0 {
    self.deepest = path.length()
    self.diagnostic = { path, rule: self.root, message, }
  }
  false
}

///|
/// Success returns None; a mismatch returns one deterministic witness diagnostic.
/// Resource exhaustion raises Limit and never returns a false success/mismatch.
pub fn Schema::validate(
  self : Schema,
  value : Value,
  work_limit~ : Int32 = 100000,
) -> Diagnostic? raise CddlError {
  if work_limit < 1 || work_limit > 1000000 {
    raise Limit("work_limit must be 1..1000000")
  }
  let ctx = Context::{
    rules: self.rules,
    root: self.root,
    remaining: work_limit,
    stack: 0,
    deepest: 0,
    diagnostic: {
      path: "",
      rule: self.root,
      message: "value does not match schema",
    },
  }
  check_value(value, ctx, 0)
  let node = match self.rules.get(self.root) {
    Some(node) => node
    None => raise InvalidSchema("missing root")
  }
  if matches(node, value, "", ctx, 0) {
    None
  } else {
    Some(ctx.diagnostic)
  }
}

///|
/// Validate a complete JSON document; numbers outside the exact safe integer
/// domain are rejected by this adapter instead of silently losing precision.
pub fn Schema::validate_json(
  self : Schema,
  text : String,
  work_limit~ : Int32 = 100000,
) -> Diagnostic? raise CddlError {
  self.validate(from_json(text), work_limit~)
}

///|
pub fn from_json(text : String) -> Value raise CddlError {
  if text.length() > 1048576 {
    raise Limit("JSON text exceeds 1048576 UTF-16 units")
  }
  json_preflight(text)
  let json = @json.parse(text) catch { _ => raise InvalidData("invalid JSON") }
  json_value(json, 0)
}

///|
/// Bound nesting before invoking the standard parser, and reject duplicate keys
/// rather than letting its object map silently keep the last value.
fn json_preflight(text : String) -> Unit raise CddlError {
  let kinds : Array[Bool] = []
  let names : Array[Map[String, Bool]] = []
  let mut i = 0
  while i < text.length() {
    let c = text[i]
    if c == '"' {
      let start = i
      i = i + 1
      while i < text.length() && text[i] != '"' {
        if text[i] == '\\' {
          i = i + 1
        }
        i = i + 1
      }
      if i >= text.length() {
        raise InvalidData("unterminated JSON string")
      }
      i = i + 1
      let mut next = i
      while next < text.length() &&
            (
              text[next] == ' ' ||
              text[next] == '\r' ||
              text[next] == '\n' ||
              text[next] == '\t'
            ) {
        next = next + 1
      }
      if next < text.length() &&
        text[next] == ':' &&
        kinds.length() > 0 &&
        kinds[kinds.length() - 1] {
        let key = match
          (@json.parse(text[start:i]) catch {
            _ => raise InvalidData("invalid JSON key")
          }) {
          String(s) => s
          _ => raise InvalidData("invalid JSON key")
        }
        let seen = names[names.length() - 1]
        if seen.contains(key) {
          raise InvalidData("duplicate JSON key: " + key)
        }
        seen.set(key, true)
      }
      continue
    }
    if (c >= '0' && c <= '9') || c == '-' {
      let start = i
      i = i + 1
      while i < text.length() {
        let d = text[i]
        if (d >= '0' && d <= '9') ||
          d == '.' ||
          d == 'e' ||
          d == 'E' ||
          d == '+' ||
          d == '-' {
          i = i + 1
        } else {
          break
        }
      }
      exact_json_integer(text[start:i].to_owned())
      continue
    }
    if c == '{' || c == '[' {
      kinds.push(c == '{')
      names.push(Map([]))
      if kinds.length() > 64 {
        raise Limit("JSON nesting exceeds 64")
      }
    } else if c == '}' || c == ']' {
      if kinds.length() == 0 {
        raise InvalidData("unbalanced JSON collection")
      }
      ignore(kinds.pop())
      ignore(names.pop())
    }
    i = i + 1
  }
}

///|
/// Do not let floating-point rounding turn a fractional JSON token into a valid
/// integer (e.g. 9007199254740990.1 or an underflowing 1e-999).
fn exact_json_integer(raw : String) -> Unit raise CddlError {
  if raw.length() > 1024 {
    raise Limit("JSON numeric token exceeds 1024 units")
  }
  let json = @json.parse(raw) catch {
    _ => raise InvalidData("invalid JSON number")
  }
  guard json is Number(n, ..) else { raise InvalidData("invalid JSON number") }
  if n.is_nan() || n.is_inf() {
    raise InvalidData("non-finite JSON number")
  }
  if @double.floor(n) != n {
    return
  }
  let parts = raw.to_lower().split("e").to_array()
  let exponent = if parts.length() == 2 {
    @string.parse_int(parts[1]) catch {
      _ => raise InvalidData("JSON exponent outside supported range")
    }
  } else {
    0
  }
  if exponent < -10000 || exponent > 10000 {
    raise InvalidData("JSON exponent outside supported range")
  }
  let mantissa = parts[0].to_owned()
  let negative = mantissa.has_prefix("-")
  let unsigned = if negative { mantissa[1:].to_owned() } else { mantissa }
  let decimal = unsigned.split(".").to_array()
  let fraction = if decimal.length() == 2 { decimal[1].length() } else { 0 }
  let digits = unsigned.replace_all(old=".", new="")
  let mut leading = 0
  while leading < digits.length() && digits[leading] == '0' {
    leading = leading + 1
  }
  if leading == digits.length() {
    return
  }
  let digits = digits[leading:].to_owned()
  let scale = exponent - fraction
  let canonical = if scale >= 0 {
    if digits.length() + scale > 16 {
      raise InvalidData("JSON integer exceeds exact safe integer domain")
    }
    digits + "0".repeat(scale)
  } else {
    let cut = -scale
    if cut >= digits.length() ||
      !digits[digits.length() - cut:].iter().all(c => c == '0') {
      raise InvalidData(
        "fractional JSON number rounded to an integer; use CBOR or a representable number",
      )
    }
    digits[:digits.length() - cut].to_owned()
  }
  let exact = @string.parse_int64(canonical) catch {
    _ => raise InvalidData("JSON integer exceeds exact safe integer domain")
  }
  if exact > 9007199254740991L ||
    (if negative { -exact } else { exact }) != n.to_int64() {
    raise InvalidData("JSON integer exceeds exact safe integer domain")
  }
}

///|
fn json_value(json : Json, depth : Int32) -> Value raise CddlError {
  if depth > 64 {
    raise Limit("JSON nesting exceeds 64")
  }
  match json {
    Null => Null
    True => Boolean(true)
    False => Boolean(false)
    String(s) => Text(s)
    Number(n, ..) => {
      if n.is_nan() || n.is_inf() {
        raise InvalidData("non-finite JSON number")
      }
      if @double.floor(n) == n {
        if n < -9007199254740991.0 || n > 9007199254740991.0 {
          raise InvalidData(
            "JSON integer exceeds exact safe integer domain; use Value or CBOR",
          )
        }
        Integer(n.to_int64())
      } else {
        Real(n)
      }
    }
    Array(values) => List(values.map(v => json_value(v, depth + 1)))
    Object(fields) => {
      let out : Array[(Value, Value)] = []
      let keys = fields.keys().to_array()
      keys.sort()
      for key in keys {
        if fields.get(key) is Some(value) {
          out.push((Text(key), json_value(value, depth + 1)))
        }
      }
      Dict(out)
    }
  }
}

///|
fn check_value(
  value : Value,
  ctx : Context,
  depth : Int32,
) -> Unit raise CddlError {
  ctx.enter()
  defer {
    ctx.stack = ctx.stack - 1
  }
  ctx.step(depth)
  match value {
    List(items) =>
      for item in items {
        check_value(item, ctx, depth + 1)
      }
    Dict(pairs) => {
      if pairs.length() > 128 {
        raise Limit("maps are limited to 128 members in profile v1")
      }
      for i, (key, item) in pairs {
        match key {
          Text(_) | Integer(_) => ()
          _ =>
            raise InvalidData(
              "map keys must be text or signed 64-bit integers in profile v1",
            )
        }
        for j in 0..<i {
          ctx.step(depth)
          if pairs[j].0 == key {
            raise InvalidData("duplicate map key")
          }
        }
        check_value(item, ctx, depth + 1)
      }
    }
    Tagged(tag, item) => {
      if tag < 0 {
        raise InvalidData("tag must be nonnegative")
      }
      check_value(item, ctx, depth + 1)
    }
    _ => ()
  }
}

///|
fn pointer(path : String, key : Value) -> String {
  let text = match key {
    Text(s) => s
    Integer(n) => "\{n}"
    _ => "?"
  }
  path +
  "/" +
  text.replace_all(old="~", new="~0").replace_all(old="/", new="~1")
}

///|
fn matches(
  node : Node,
  value : Value,
  path : String,
  ctx : Context,
  depth : Int32,
) -> Bool raise CddlError {
  ctx.enter()
  defer {
    ctx.stack = ctx.stack - 1
  }
  ctx.step(depth)
  let ok = match node {
    Primitive(name) =>
      match (name, value) {
        ("any", _) => true
        ("uint", Integer(n)) => n >= 0
        ("nint", Integer(n)) => n < 0
        ("int", Integer(_)) => true
        ("float", Real(_)) => true
        ("bool", Boolean(_)) => true
        ("tstr" | "text", Text(_)) => true
        ("bstr" | "bytes", Binary(_)) => true
        _ => false
      }
    Literal(expected) => expected == value
    Range(lower, upper, inclusive) =>
      match value {
        Integer(n) =>
          n >= lower && (if inclusive { n <= upper } else { n < upper })
        _ => false
      }
    Ref(name) =>
      match ctx.rules.get(name) {
        Some(child) => matches(child, value, path, ctx, depth + 1)
        None => raise InvalidSchema("undefined rule: " + name)
      }
    Choice(nodes) => {
      let mut found = false
      for child in nodes {
        if matches(child, value, path, ctx, depth + 1) {
          found = true
          break
        }
      }
      found
    }
    Sized(child, lower, upper) =>
      if !matches(child, value, path, ctx, depth + 1) {
        false
      } else {
        match value {
          Text(s) => {
            let n = @utf8.encode(s[:]).length().to_int64()
            n >= lower && n <= upper
          }
          Binary(bytes) => {
            let n = bytes.length().to_int64()
            n >= lower && n <= upper
          }
          Integer(n) if n >= 0 && lower == upper =>
            // uint .size N denotes a maximum capacity, not the wire encoding.
            if upper >= 8 {
              true
            } else {
              n < 1L << (upper.to_int() * 8)
            }
          _ =>
            raise InvalidSchema(
              ".size requires text, bytes, or uint with a single integer size",
            )
        }
      }
    Sequence(entries) =>
      match value {
        List(items) => sequence(entries, 0, items, 0, path, ctx, depth + 1)
        _ => false
      }
    Record(entries) =>
      match value {
        Dict(pairs) =>
          record(
            entries,
            0,
            pairs,
            Array::make(pairs.length(), false),
            0,
            path,
            ctx,
            depth + 1,
          )
        _ => false
      }
    Tag(tag, child) =>
      match value {
        Tagged(actual, item) =>
          actual == tag && matches(child, item, path, ctx, depth + 1)
        _ => false
      }
  }
  if ok {
    true
  } else {
    ctx.reject(path, "value does not match the CDDL type at this path")
  }
}

///|
/// Backtracking is necessary: [* int, int] must not greedily consume its tail.
fn sequence(
  entries : Array[Entry],
  entry_index : Int32,
  items : Array[Value],
  item_index : Int32,
  path : String,
  ctx : Context,
  depth : Int32,
) -> Bool raise CddlError {
  ctx.enter()
  defer {
    ctx.stack = ctx.stack - 1
  }
  ctx.step(depth)
  if entry_index == entries.length() {
    return item_index == items.length()
  }
  let entry = entries[entry_index]
  let mut matched = 0
  while matched < entry.maximum && item_index + matched < items.length() {
    if !matches(
        entry.value,
        items[item_index + matched],
        path + "/\{item_index + matched}",
        ctx,
        depth + 1,
      ) {
      break
    }
    matched = matched + 1
  }
  let mut amount = matched
  while amount >= entry.minimum {
    if sequence(
        entries,
        entry_index + 1,
        items,
        item_index + amount,
        path,
        ctx,
        depth,
      ) {
      return true
    }
    amount = amount - 1
  }
  ctx.reject(
    path + "/\{item_index}",
    "array occurrence or trailing-item mismatch",
  )
}

///|
/// Match unordered maps by assigning each pair to exactly one entry. Alternative
/// assignments are explored; a shared global budget bounds ambiguous schemas.
fn record(
  entries : Array[Entry],
  index : Int32,
  pairs : Array[(Value, Value)],
  used : Array[Bool],
  count : Int32,
  path : String,
  ctx : Context,
  depth : Int32,
) -> Bool raise CddlError {
  ctx.enter()
  defer {
    ctx.stack = ctx.stack - 1
  }
  ctx.step(depth)
  if index == entries.length() {
    for i, occupied in used {
      if !occupied {
        return ctx.reject(pointer(path, pairs[i].0), "unexpected map key")
      }
    }
    return true
  }
  let entry = entries[index]
  if count >= entry.minimum &&
    record(entries, index + 1, pairs, used, 0, path, ctx, depth) {
    return true
  }
  if count < entry.maximum {
    for i, (key, value) in pairs {
      ctx.step(depth)
      if used[i] {
        continue
      }
      let key_type = match entry.key {
        Some(node) => node
        None => raise InvalidSchema("record entry has no key")
      }
      // Failed key candidates do not represent invalid values at their paths.
      let saved = ctx.diagnostic
      let saved_depth = ctx.deepest
      let key_matches = matches(key_type, key, path, ctx, depth + 1)
      ctx.diagnostic = saved
      ctx.deepest = saved_depth
      if key_matches &&
        matches(entry.value, value, pointer(path, key), ctx, depth + 1) {
        used[i] = true
        let ok = record(
          entries,
          index,
          pairs,
          used,
          count + 1,
          path,
          ctx,
          depth,
        )
        used[i] = false
        if ok {
          return true
        }
      }
    }
  }
  ctx.reject(path, "missing or invalid map member")
}
