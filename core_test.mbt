///|
fn accepts(schema : String, data : String) -> Bool raise {
  @mooncddl.compile(schema).validate_json(data) is None
}

///|
test "records are closed unordered and optional" {
  assert_true(accepts("root = {id: uint, ? name: tstr}", "{\"id\":1}"))
  assert_true(
    accepts("root = {id: uint, ? name: tstr}", "{\"name\":\"甲\",\"id\":1}"),
  )
  assert_false(accepts("root = {id: uint}", "{\"id\":1,\"extra\":0}"))
  assert_false(accepts("root = {id: uint}", "{}"))
}

///|
test "array repetition backtracks to preserve required tail" {
  assert_true(accepts("root = [* int, int]", "[1,2,3]"))
  assert_false(accepts("root = [* int, int]", "[]"))
  assert_true(accepts("root = [? int, int]", "[1]"))
  assert_true(accepts("root = [2*3 uint]", "[1,2,3]"))
  assert_false(accepts("root = [2*3 uint]", "[1]"))
}

///|
test "choices ranges and referenced types" {
  let source = "root = [level, level] level = 0..3 / \"auto\""
  assert_true(accepts(source, "[3,\"auto\"]"))
  assert_false(accepts(source, "[4,0]"))
  assert_true(accepts("root = -2...3", "2"))
  assert_false(accepts("root = -2...3", "3"))
}

///|
test "UTF8 byte size differs from character count" {
  assert_true(accepts("root = tstr .size 3", "\"猫\""))
  assert_false(accepts("root = tstr .size 1", "\"猫\""))
  assert_true(accepts("root = tstr .size (1..4)", "\"🐱\""))
  assert_true(accepts("root = uint .size 1", "255"))
  assert_false(accepts("root = uint .size 1", "256"))
}

///|
test "map wildcard and fixed key can share key space" {
  assert_true(
    accepts(
      "root = { * tstr => int, fixed: tstr }", "{\"a\":1,\"fixed\":\"ok\"}",
    ),
  )
  assert_false(
    accepts(
      "root = { * tstr => int, fixed: tstr }", "{\"a\":\"bad\",\"fixed\":\"ok\"}",
    ),
  )
}

///|
test "recursive consuming types validate trees" {
  assert_true(accepts("root = int / [* root]", "[1,[2,3],[]]"))
  assert_false(accepts("root = int / [* root]", "[1,[false]]"))
}

///|
test "unsupported constructs and non-consuming cycles fail compilation" {
  for
    source in [
      "root = missing", "root = root / int", "root = int root = tstr", "root = tstr .regexp \"a\"",
      "root = (a: int)", "root = 0x10", "root /= int", "root = [int // tstr]",
    ] {
    try @mooncddl.compile(source) catch {
      _ => ()
    } noraise {
      _ => fail("unexpected compilation success: " + source)
    }
  }
}

///|
test "limits and exact-number errors are not successful validations" {
  let schema = @mooncddl.compile("root = [* any]")
  try schema.validate_json("[1,2,3]", work_limit=1) catch {
    @mooncddl.Limit(_) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected limit")
  }
  try @mooncddl.from_json("9007199254740993") catch {
    @mooncddl.InvalidData(_) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("expected precision error")
  }
}

///|
test "CBOR-oriented values preserve bytes integer keys and tags" {
  let schema = @mooncddl.compile("root = #6.18({1: bstr .size 2})")
  let value = @mooncddl.Tagged(
    18,
    @mooncddl.Dict([(@mooncddl.Integer(1), @mooncddl.Binary(b"ab"))]),
  )
  assert_eq(schema.validate(value), None)
}

///|
test "diagnostic uses escaped JSON pointer" {
  let schema = @mooncddl.compile("root = {\"a/b~c\": uint}")
  guard schema.validate_json("{\"a/b~c\":-1}") is Some(error) else {
    fail("expected mismatch")
  }
  assert_eq(error.path, "/a~1b~0c")
}
