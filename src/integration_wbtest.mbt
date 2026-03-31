///|
/// A simple adjacency-list graph using Array[Array[Int]] for testing.
/// Proves that an external data structure can implement DirectedGraph
/// and use all algorithms without modification.
struct ArrayGraph {
  successors : Array[Array[Int]]
}

///|
impl DirectedGraph for ArrayGraph with vertex_count(self) {
  self.successors.length()
}

///|
impl DirectedGraph for ArrayGraph with for_each_vertex(self, f) {
  for i = 0; i < self.successors.length(); i = i + 1 {
    f(i)
  }
}

///|
impl DirectedGraph for ArrayGraph with for_each_successor(self, v, f) {
  if v >= 0 && v < self.successors.length() {
    let succs = self.successors[v]
    for i = 0; i < succs.length(); i = i + 1 {
      f(succs[i])
    }
  }
}

///|
test "external impl: reachable" {
  // 0 → 1 → 2 → 3
  let g : ArrayGraph = { successors: [[1], [2], [3], []] }
  let r = reachable(g, 0)
  assert_eq(r.length(), 4)
}

///|
test "external impl: toposort" {
  let g : ArrayGraph = { successors: [[1], [2], [3], []] }
  let result = toposort(g)
  assert_true(result is Some(_))
  match result {
    Some(order) => assert_eq(order.length(), 4)
    None => assert_true(false)
  }
}

///|
test "external impl: has_cycle" {
  // Acyclic
  let g : ArrayGraph = { successors: [[1], [2], [3], []] }
  assert_true(!has_cycle(g))
}

///|
test "external impl: has_cycle true" {
  // 0 → 1 → 2 → 0 (cycle)
  let g : ArrayGraph = { successors: [[1], [2], [0]] }
  assert_true(has_cycle(g))
}

///|
test "external impl: bfs_fold" {
  let g : ArrayGraph = { successors: [[1, 2], [3], [3], []] }
  let order : Array[Int] = bfs_fold(g, 0, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(order.length(), 4)
  assert_eq(order[0], 0)
  // 3 should be last
  assert_eq(order[3], 3)
}

///|
test "external impl: dfs_fold" {
  let g : ArrayGraph = { successors: [[1], [2], [3], []] }
  let visited = dfs_fold(g, 0, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  assert_eq(visited.length(), 4)
}

// --- has_vertex dispatch tests ---
//
// These three tests verify the two-tier default/override design:
// - ArrayGraph omits has_vertex → uses O(V) default (for_each_vertex scan)
// - AdjacencyMap overrides has_vertex → O(1) via Map::contains
// - DenseGraph overrides has_vertex → O(1) via range check
// All three must produce correct results through trait dispatch.

///|
test "default has_vertex works on ArrayGraph" {
  // ArrayGraph overrides vertex_count but NOT has_vertex.
  // This exercises the O(V) default from traits.mbt, proving
  // the default impl is dispatched when no override exists.
  let g = ArrayGraph::{ successors: [[1, 2], [2], [3], []] }
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 3))
  assert_true(!DirectedGraph::has_vertex(g, 4))
  assert_true(!DirectedGraph::has_vertex(g, -1))
}

///|
test "has_vertex O(1) override on AdjacencyMap" {
  // AdjacencyMap provides an O(1) override (Map::contains).
  // Calling through DirectedGraph:: verifies the trait impl is
  // dispatched, not just the standalone AdjacencyMap::has_vertex.
  let g = AdjacencyMap::from_edges([(0, 1), (1, 2)])
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 2))
  assert_true(!DirectedGraph::has_vertex(g, 3))
  assert_true(!DirectedGraph::has_vertex(g, -1))
}

///|
test "has_vertex O(1) override on DenseGraph" {
  // DenseGraph overrides has_vertex with a range check (v >= 0 && v < n).
  // Vertex 3 is out of range for a 3-vertex graph (valid: 0, 1, 2).
  // Negative IDs are always invalid.
  let g = DenseGraph::from_edges(3, [(0, 1), (1, 2)])
  assert_true(DirectedGraph::has_vertex(g, 0))
  assert_true(DirectedGraph::has_vertex(g, 2))
  assert_true(!DirectedGraph::has_vertex(g, 3))
  assert_true(!DirectedGraph::has_vertex(g, -1))
}
