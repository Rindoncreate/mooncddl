///|
/// CBOR decoding is delegated to the existing ecosystem codec. A wire envelope
/// preflight bounds nesting, declared lengths and total items before it recurses.
pub fn decode(bytes : Bytes) -> @cddl.Value raise @cddl.CddlError {
  if bytes.length() > 1048576 {
    raise @cddl.Limit("CBOR input exceeds 1 MiB")
  }
  let cursor = Cursor::{ bytes, offset: 0, nodes: 0, }
  cursor.scan(0)
  if cursor.offset != bytes.length() {
    raise @cddl.InvalidData("trailing CBOR data")
  }
  let value = @codec.decode(bytes) catch {
    _ => raise @cddl.InvalidData("invalid CBOR encoding")
  }
  convert(value, 0)
}

///|
pub fn validate(
  schema : @cddl.Schema,
  bytes : Bytes,
  work_limit~ : Int32 = 100000,
) -> @cddl.Diagnostic? raise @cddl.CddlError {
  schema.validate(decode(bytes), work_limit~)
}

///|
priv struct Cursor {
  bytes : Bytes
  mut offset : Int32
  mut nodes : Int32
}

///|
fn Cursor::byte(self : Cursor) -> Int32 raise @cddl.CddlError {
  if self.offset >= self.bytes.length() {
    raise @cddl.InvalidData("truncated CBOR")
  }
  let n = self.bytes[self.offset].to_int()
  self.offset = self.offset + 1
  n
}

///|
fn Cursor::argument(self : Cursor, ai : Int32) -> UInt64 raise @cddl.CddlError {
  if ai < 24 {
    return ai.to_uint64()
  }
  let count = match ai {
    24 => 1
    25 => 2
    26 => 4
    27 => 8
    _ => raise @cddl.InvalidData("reserved CBOR additional information")
  }
  let mut n = 0UL
  for _ in 0..<count {
    n = (n << 8) | self.byte().to_uint64()
  }
  n
}

///|
fn Cursor::skip(self : Cursor, n : UInt64) -> Unit raise @cddl.CddlError {
  if n > (self.bytes.length() - self.offset).to_uint64() {
    raise @cddl.InvalidData("CBOR length exceeds available input")
  }
  self.offset = self.offset + n.to_int()
}

///|
fn Cursor::scan(self : Cursor, depth : Int32) -> Unit raise @cddl.CddlError {
  if depth > 64 {
    raise @cddl.Limit("CBOR nesting exceeds 64")
  }
  self.nodes = self.nodes + 1
  if self.nodes > 10000 {
    raise @cddl.Limit("CBOR exceeds 10000 encoded items")
  }
  let head = self.byte()
  let major = head >> 5
  let ai = head & 31
  if ai == 31 {
    if major < 2 || major > 5 {
      raise @cddl.InvalidData("invalid CBOR indefinite item")
    }
    let mut count = 0
    while true {
      if self.offset >= self.bytes.length() {
        raise @cddl.InvalidData("unterminated CBOR indefinite item")
      }
      if self.bytes[self.offset] == b'\xff' {
        self.offset = self.offset + 1
        break
      }
      if major == 2 || major == 3 {
        let chunk = self.bytes[self.offset].to_int()
        if chunk >> 5 != major || (chunk & 31) == 31 {
          raise @cddl.InvalidData("invalid CBOR string chunk")
        }
      }
      self.scan(depth + 1)
      count = count + 1
    }
    if major == 5 && count % 2 != 0 {
      raise @cddl.InvalidData("odd number of CBOR map items")
    }
    return
  }
  let n = self.argument(ai)
  match major {
    0 | 1 =>
      if n > 9223372036854775807UL {
        raise @cddl.InvalidData("integer exceeds signed 64-bit profile")
      }
    2 | 3 => self.skip(n)
    4 | 5 => {
      if n > 10000UL {
        raise @cddl.Limit("CBOR collection exceeds item budget")
      }
      let count = n.to_int() * (if major == 5 { 2 } else { 1 })
      for _ in 0..<count {
        self.scan(depth + 1)
      }
    }
    6 => self.scan(depth + 1)
    7 =>
      if ai == 24 && n < 32UL {
        raise @cddl.InvalidData("invalid CBOR simple value")
      }
    _ => raise @cddl.InvalidData("invalid CBOR major type")
  }
}

///|
fn convert(
  value : @codec.CborValue,
  depth : Int32,
) -> @cddl.Value raise @cddl.CddlError {
  if depth > 64 {
    raise @cddl.Limit("CBOR conversion nesting exceeds 64")
  }
  match value {
    Unsigned(n) => {
      if n > 9223372036854775807UL {
        raise @cddl.InvalidData("CBOR uint exceeds signed 64-bit profile")
      }
      @cddl.Integer(n.reinterpret_as_int64())
    }
    Integer(n) => @cddl.Integer(n)
    Bytes(bytes) => @cddl.Binary(bytes)
    Text(s) => @cddl.Text(s)
    Array(items) => @cddl.List(items.map(v => convert(v, depth + 1)))
    Map(pairs) =>
      @cddl.Dict(
        pairs.map(pair => {
          (convert(pair.0, depth + 1), convert(pair.1, depth + 1))
        }),
      )
    Tag(tag, item) => {
      if tag > 9223372036854775807UL {
        raise @cddl.InvalidData("CBOR tag exceeds signed 64-bit profile")
      }
      @cddl.Tagged(tag.reinterpret_as_int64(), convert(item, depth + 1))
    }
    Simple(b'\x14') => @cddl.Boolean(false)
    Simple(b'\x15') => @cddl.Boolean(true)
    Simple(b'\x16') => @cddl.Null
    Simple(_) => raise @cddl.InvalidData("unsupported CBOR simple value")
    Float64(n) => @cddl.Real(n)
  }
}
