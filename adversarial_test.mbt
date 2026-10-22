///|
test "unused unsupported rules cannot be hidden behind valid root" {
  for
    source in [
      "root = any unused = bool .size 1", "root = any unused = uint .size (1..2)",
      "root = any unused = missing", "root = any unused = unused",
    ] {
    try @mooncddl.compile(source) catch {
      _ => ()
    } noraise {
      _ => fail("expected whole-schema rejection")
    }
  }
}

///|
test "JSON duplicate keys are rejected even when escape spellings differ" {
  let schema = @mooncddl.compile("root = any")
  for
    text in [
      "{\"id\":1,\"id\":2}", "{\"a\":1,\"\\u0061\":2}", "{\"x\":{\"a\":0,\"a\":1}}",
    ] {
    try schema.validate_json(text) catch {
      @mooncddl.InvalidData(_) => ()
      _ => fail("wrong error")
    } noraise {
      _ => fail("duplicate JSON passed")
    }
  }
  assert_eq(schema.validate_json("{\"a\":{\"a\":1},\"b\":{\"a\":2}}"), None)
}

///|
test "source and nesting budgets fail explicitly" {
  let source = "root = " + "[".repeat(70) + "int" + "]".repeat(70)
  try @mooncddl.compile(source) catch {
    @mooncddl.Limit(_) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("unbounded schema nesting")
  }
  let schema = @mooncddl.compile("root = any")
  let text = "[".repeat(70) + "0" + "]".repeat(70)
  try schema.validate_json(text) catch {
    @mooncddl.Limit(_) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("unbounded JSON nesting")
  }
}

///|
test "explicit root selection and invalid budgets" {
  let schema = @mooncddl.compile("a = int b = tstr", root="b")
  assert_eq(schema.validate_json("\"ok\""), None)
  assert_true(schema.validate_json("1") is Some(_))
  try schema.validate_json("1", work_limit=0) catch {
    @mooncddl.Limit(_) => ()
    _ => fail("wrong error")
  } noraise {
    _ => fail("budget was ignored")
  }
}

///|
test "all supported signed integer endpoints remain exact" {
  let schema = @mooncddl.compile(
    "root = -9223372036854775808..9223372036854775807",
  )
  assert_eq(schema.validate(@mooncddl.Integer(-9223372036854775808L)), None)
  assert_eq(schema.validate(@mooncddl.Integer(9223372036854775807L)), None)
}

///|
test "fractional rounding and underflow cannot become valid integers" {
  for
    text in [
      "9007199254740990.1", "1e-999", "1.00000000000000000001", "-1e-999",
    ] {
    try @mooncddl.from_json(text) catch {
      @mooncddl.InvalidData(_) => ()
      _ => fail("wrong error")
    } noraise {
      _ => fail("lossy JSON number passed")
    }
  }
  for text in ["1.0", "10e-1", "0e-999", "100.000", "1e3", "9007199254740991"] {
    assert_true(@mooncddl.compile("root = uint").validate_json(text) is None)
  }
}
