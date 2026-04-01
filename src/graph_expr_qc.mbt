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
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
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
    },
    max_success=100,
  )
}

///|
/// Property: dfs_events emits exactly one Discover and one Finish per vertex.
test "prop: dfs_events Discover/Finish count matches vertex_count" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let events = dfs_events(am).collect()
      let mut discovers = 0
      let mut finishes = 0
      for e in events.iter() {
        match e {
          Discover(_) => discovers = discovers + 1
          Finish(_) => finishes = finishes + 1
          _ => ()
        }
      }
      let vc = am.vertex_count()
      discovers == vc && finishes == vc
    },
    max_success=100,
  )
}

///|
/// Property: every edge is classified exactly once.
/// Total classified edges (tree + back + cross/forward) equals edge_count.
test "prop: dfs_events classifies all edges" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let events = dfs_events(am).collect()
      let mut edge_events = 0
      for e in events.iter() {
        match e {
          TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
            edge_events = edge_events + 1
          _ => ()
        }
      }
      edge_events == am.edge_count()
    },
    max_success=100,
  )
}

///|
/// Property: reversed(g).successors(v) == g.predecessors(v) for all vertices.
test "prop: reversed successors match predecessors" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rev = reversed(am)
      for v in DirectedGraph::iter(am) {
        let preds = Predecessors::predecessors(am, v).collect()
        let rev_succs = DirectedGraph::successors(rev, v).collect()
        preds.sort()
        rev_succs.sort()
        if preds != rev_succs {
          return false
        }
      }
      true
    },
    max_success=100,
  )
}

///|
/// Property: reversed(reversed(g)) produces same dfs_events as g.
test "prop: reversed involution preserves dfs_events" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rr = reversed(reversed(am))
      let events_orig = dfs_events(am).collect()
      let events_rr = dfs_events(rr).collect()
      if events_orig.length() != events_rr.length() {
        return false
      }
      for i = 0; i < events_orig.length(); i = i + 1 {
        if events_orig[i] != events_rr[i] {
          return false
        }
      }
      true
    },
    max_success=100,
  )
}

///|
/// Property: edge count is preserved under reversal.
test "prop: reversed preserves edge count" {
  @qc.quick_check_fn(
    fn(g : Graph) -> Bool {
      let am = g.to_adjacency_map()
      let rev = reversed(am)
      let mut orig_edges = 0
      let mut rev_edges = 0
      for e in dfs_events(am) {
        match e {
          TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
            orig_edges = orig_edges + 1
          _ => ()
        }
      }
      for e in dfs_events(rev) {
        match e {
          TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
            rev_edges = rev_edges + 1
          _ => ()
        }
      }
      orig_edges == rev_edges
    },
    max_success=100,
  )
}
