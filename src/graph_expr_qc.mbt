///|
/// Arbitrary implementation for Graph.
/// Generates random graph expressions with bounded depth.
/// Uses small vertex IDs (0..size) to increase chance of structural overlap.
/// Depth capped at 4 to keep expression trees manageable (max ~16 leaves).
pub impl @coreqc.Arbitrary for Graph with arbitrary(size, rs) {
  fn go(depth : Int, rs : @splitmix.RandomState) -> Graph {
    if depth <= 0 {
      // 2/3 Vertex, 1/3 Empty at leaves — biases toward non-trivial graphs
      if rs.next_int() % 3 == 0 {
        Empty
      } else {
        Vertex(rs.next_int().abs() % (size + 1))
      }
    } else {
      // Equal probability: Empty, Vertex, Overlay, Connect
      let branch = rs.next_int() % 4
      if branch == 0 {
        Empty
      } else if branch == 1 {
        Vertex(rs.next_int().abs() % (size + 1))
      } else if branch == 2 {
        Overlay(go(depth - 1, rs), go(depth - 1, rs))
      } else {
        Connect(go(depth - 1, rs), go(depth - 1, rs))
      }
    }
  }

  let depth = if size < 4 { size } else { 4 }
  go(depth, rs)
}

///|
/// Shrink implementation for Graph.
/// Yields candidates in order of simplicity:
/// 1. Whole subexpressions (drop one side)
/// 2. Weakened form (Connect→Overlay)
/// 3. Collapse to Empty
/// 4. Recursive shrinks inside each child (preserves constructor)
pub impl @qc.Shrink for Graph with shrink(self) {
  match self {
    Empty => Iter::empty()
    Vertex(_) => [Empty].iter()
    Overlay(a, b) =>
      // Subexpressions first, then shrink inside each child
      [a, b, Empty]
      .iter()
      .concat(@qc.Shrink::shrink(a).map(fn(a1) { Overlay(a1, b) }))
      .concat(@qc.Shrink::shrink(b).map(fn(b1) { Overlay(a, b1) }))
    Connect(a, b) =>
      // Subexpressions, weaken to Overlay, then shrink inside each child
      [a, b, Overlay(a, b), Empty]
      .iter()
      .concat(@qc.Shrink::shrink(a).map(fn(a1) { Connect(a1, b) }))
      .concat(@qc.Shrink::shrink(b).map(fn(b1) { Connect(a, b1) }))
  }
}
