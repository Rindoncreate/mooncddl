///|
/// A representation-independent data model. Maps retain non-string CBOR keys.
pub(all) enum Value {
  Integer(Int64)
  Real(Double)
  Text(String)
  Binary(Bytes)
  Boolean(Bool)
  Null
  List(Array[Value])
  Dict(Array[(Value, Value)])
  Tagged(Int64, Value)
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
/// Compilation and resource errors are distinct from a data mismatch.
pub(all) suberror CddlError {
  Syntax(Int32, String)
  Unsupported(Int32, String)
  InvalidSchema(String)
  Limit(String)
  InvalidData(String)
} derive(Debug)

///|
pub extend CddlError with @debug.Debug::{to_repr}

///|
pub(all) struct Diagnostic {
  path : String
  rule : String
  message : String
} derive(Eq, Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
enum Node {
  Primitive(String)
  Literal(Value)
  Ref(String)
  Choice(Array[Node])
  Range(Int64, Int64, Bool)
  Sized(Node, Int64, Int64)
  Sequence(Array[Entry])
  Record(Array[Entry])
  Tag(Int64, Node)
}

///|
priv struct Entry {
  key : Node?
  value : Node
  minimum : Int32
  maximum : Int32
}

///|
/// Compiled rules are private; callers cannot mutate compilation invariants.
pub struct Schema {
  priv rules : Map[String, Node]
  priv root : String
}

///|
/// The frozen semantic profile is intentionally smaller than all of RFC 8610.
pub fn profile() -> String {
  "rfc8610-structural-v1"
}
