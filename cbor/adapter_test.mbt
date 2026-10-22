///|
test "decode real CBOR with integer keys byte strings and tags" {
  let schema = @cddl.compile("root = #6.18({1: bstr .size 2})")
  assert_eq(@cbor.validate(schema, b"\xd2\xa1\x01\x42ab"), None)
  assert_true(@cbor.validate(schema, b"\xd2\xa1\x01\x41a") is Some(_))
}

///|
test "booleans null and indefinite arrays use ecosystem codec" {
  let schema = @cddl.compile("root = [true, false, nil]")
  assert_eq(@cbor.validate(schema, b"\x9f\xf5\xf4\xf6\xff"), None)
}

///|
test "malformed and trailing input fail before validation" {
  for
    bytes in [
      b"", b"\x1c", b"\xff", b"\x18", b"\x81", b"\xa1\x01", b"\x01\x02", b"\x5f\x61x\xff",
      b"\x7b\xff\xff\xff\xff\xff\xff\xff\xff",
    ] {
    try @cbor.decode(bytes) catch {
      _ => ()
    } noraise {
      _ => fail("expected CBOR error")
    }
  }
}

///|
test "duplicate integer keys are rejected" {
  let schema = @cddl.compile("root = {* int => int}")
  try @cbor.validate(schema, b"\xa2\x01\x02\x01\x03") catch {
    @cddl.InvalidData(_) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected duplicate key error")
  }
}
