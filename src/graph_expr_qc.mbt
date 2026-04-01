///|
/// Arbitrary implementation for Graph.
/// Generates random graph expressions with bounded depth.
/// Uses small vertex IDs (0..size) to increase chance of structural overlap.
/// Depth capped at 4 to keep expression trees manageable (max ~16 leaves).
pub impl @coreqc.Arbitrary for Graph with arbitrary(size, rs) {
  fn go(depth : Int, rs : @splitmix.RandomState) -> Graph {
    if depth <= 0 {
      // 2/3 Vertex, 1/3 Empty at leaves — biases toward non-trivial graphs
      if rs.next_uint() % 3 == 0 {
        Empty
      } else {
        Vertex(rs.next_positive_int() % (size + 1))
      }
    } else {
      // Equal probability: Empty, Vertex, Overlay, Connect
      match rs.next_uint() % 4 {
        0 => Empty
        1 => Vertex(rs.next_positive_int() % (size + 1))
        2 => Overlay(go(depth - 1, rs), go(depth - 1, rs))
        _ => Connect(go(depth - 1, rs), go(depth - 1, rs))
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
      [a, b, Empty]
      .iter()
      .concat(@qc.Shrink::shrink(a).map(fn(a1) { Overlay(a1, b) }))
      .concat(@qc.Shrink::shrink(b).map(fn(b1) { Overlay(a, b1) }))
    Connect(a, b) =>
      [a, b, Overlay(a, b), Empty]
      .iter()
      .concat(@qc.Shrink::shrink(a).map(fn(a1) { Connect(a1, b) }))
      .concat(@qc.Shrink::shrink(b).map(fn(b1) { Connect(a, b1) }))
  }
}

///|
/// Property: tarjan_scc and Kosaraju scc produce the same component sets.
/// Components may appear in different order, and vertices within a component
/// may appear in different order, but the sets of sets must be equal.
test "prop: tarjan_scc matches kosaraju scc" {
  @qc.quick_check_fn(fn(g : Graph) -> Bool {
    let am = g.to_adjacency_map()
    let kosaraju = am.scc()
    let tarjan = tarjan_scc(am)
    // Normalize: sort each component, then sort the list of components
    let normalize = fn(components : Array[Array[Int]]) -> Array[Array[Int]] {
      let sorted = components.map(fn(c) {
        let copy = c.copy()
        copy.sort()
        copy
      })
      sorted.sort_by(fn(a, b) {
        if a.length() == 0 && b.length() == 0 {
          return 0
        }
        if a.length() == 0 {
          return -1
        }
        if b.length() == 0 {
          return 1
        }
        a[0].compare(b[0])
      })
      sorted
    }
    let k_norm = normalize(kosaraju)
    let t_norm = normalize(tarjan)
    if k_norm.length() != t_norm.length() {
      return false
    }
    for i = 0; i < k_norm.length(); i = i + 1 {
      if k_norm[i] != t_norm[i] {
        return false
      }
    }
    true
  }, max_success=100)
}
