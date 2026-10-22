///|
/// Pure boundary: native hosts transport text/bytes; all schema decisions remain
/// in MoonBit. This exported function also makes independent differential tests possible.
pub fn check(
  schema : String,
  data : String,
  input : String,
  root : String,
) -> String {
  try {
    let compiled = @cddl.compile(schema, root~)
    let result = match input {
      "json" => compiled.validate_json(data)
      "cbor" => @adapter.validate(compiled, from_hex(data))
      _ => raise @cddl.InvalidData("input must be json or cbor")
    }
    match result {
      None =>
        report(0, "valid", "", "", "data matches the selected CDDL profile", -1)
      Some(error) =>
        report(1, "mismatch", error.path, error.rule, error.message, -1)
    }
  } catch {
    @cddl.Syntax(offset, message) =>
      report(2, "schema-error", "", root, message, offset)
    @cddl.Unsupported(offset, message) =>
      report(2, "unsupported-schema", "", root, message, offset)
    @cddl.InvalidSchema(message) =>
      report(2, "schema-error", "", root, message, -1)
    @cddl.InvalidData(message) =>
      report(3, "input-error", "", root, message, -1)
    @cddl.Limit(message) => report(4, "resource-limit", "", root, message, -1)
  }
}

///|
fn report(
  code : Int32,
  status : String,
  path : String,
  rule : String,
  message : String,
  offset : Int32,
) -> String {
  let value : Json = Json::object(
    Map([
      ("profile", Json::string(@cddl.profile())),
      ("code", Json::number(code.to_double())),
      ("status", Json::string(status)),
      ("path", Json::string(path)),
      ("rule", Json::string(rule)),
      ("message", Json::string(message)),
      ("schemaOffsetUtf16", Json::number(offset.to_double())),
    ]),
  )
  value.stringify()
}

///|
fn from_hex(text : String) -> Bytes raise @cddl.CddlError {
  if text.length() > 2097152 {
    raise @cddl.Limit("hex transport exceeds 1 MiB of CBOR")
  }
  if text.length() % 2 != 0 {
    raise @cddl.InvalidData("odd-length hexadecimal data")
  }
  let output : Array[Byte] = []
  fn digit(c : UInt16) -> Int32 raise @cddl.CddlError {
    if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      raise @cddl.InvalidData("invalid hexadecimal data")
    }
  }
  for i = 0; i < text.length(); i = i + 2 {
    output.push((digit(text[i]) * 16 + digit(text[i + 1])).to_byte())
  }
  Bytes::from_array(output)
}
