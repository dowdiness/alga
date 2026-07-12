// Deliberately-broken DirectedGraph impls used to verify that
// check_conformance flags each law violation. Each struct is minimal —
// it only implements the two required methods, and the broken one
// violates exactly one property (where possible).

///|
/// True if some violation message contains every substring in `parts`.
/// Used to tie a test to a specific message (not just "some Law X appears
/// anywhere") — combining e.g. `["Law B", "99"]` asserts that the Law B
/// violation names the offending vertex.
fn has_violation(violations : Array[String], parts : Array[String]) -> Bool {
  violations.iter().any(fn(s) { parts.iter().all(fn(p) { s.contains(p) }) })
}

///|
struct DupIter {}

///|
pub impl @alga.VertexSet for DupIter with fn iter(_self) {
  [1, 1, 2].iter()
}

///|
pub impl @alga.Successors for DupIter with fn successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for DupIter

///|
struct DanglingSucc {}

///|
pub impl @alga.VertexSet for DanglingSucc with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for DanglingSucc with fn successors(_self, v) {
  if v == 1 {
    [99].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.DirectedGraph for DanglingSucc

///|
struct DupSucc {}

///|
pub impl @alga.VertexSet for DupSucc with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for DupSucc with fn successors(_self, v) {
  if v == 1 {
    [2, 2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.DirectedGraph for DupSucc

///|
struct VertexCountLies {}

///|
pub impl @alga.VertexSet for VertexCountLies with fn iter(_self) {
  [1, 2, 3].iter()
}

///|
pub impl @alga.Successors for VertexCountLies with fn successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.VertexSet for VertexCountLies with fn vertex_count(_self) {
  7
}

///|
pub impl @alga.DirectedGraph for VertexCountLies

///|
struct HasVertexLies {}

///|
pub impl @alga.VertexSet for HasVertexLies with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for HasVertexLies with fn successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.VertexSet for HasVertexLies with fn has_vertex(_self, _v) {
  false
}

///|
test "positive: AdjacencyMap conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  @test.assert_eq(@alga.check_conformance(g), [])
}

///|
test "positive: AdjacencyMap with Predecessors conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1), (1, 3)])
  @test.assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: DenseGraph conforms" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (1, 2), (2, 0), (2, 3)])
  @test.assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: Reversed conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  @test.assert_eq(@alga.check_predecessors_conformance(@alga.reversed(g)), [])
}

///|
test "positive: empty graph conforms" {
  let g : @alga.AdjacencyMap = @alga.AdjacencyMap::empty()
  @test.assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: single vertex conforms" {
  let g = @alga.AdjacencyMap::vertex(42)
  @test.assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: self-loop conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  @test.assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "negative: Law A — duplicate iter flagged" {
  let v = @alga.check_conformance(DupIter::{  })
  assert_true(has_violation(v, ["Law A"]))
}

///|
test "negative: Law B — dangling successor flagged" {
  let v = @alga.check_conformance(DanglingSucc::{  })
  assert_true(has_violation(v, ["Law B", "99"]))
}

///|
test "negative: Law E — duplicate successor flagged" {
  let v = @alga.check_conformance(DupSucc::{  })
  assert_true(has_violation(v, ["Law E"]))
}

///|
test "negative: Law D — vertex_count mismatch flagged" {
  let v = @alga.check_conformance(VertexCountLies::{  })
  assert_true(has_violation(v, ["Law D", "7"]))
}

///|
test "negative: Law C — has_vertex lies flagged" {
  let v = @alga.check_conformance(HasVertexLies::{  })
  assert_true(has_violation(v, ["Law C"]))
}

///|
struct HasVertexLiesPositive {}

///|
pub impl @alga.VertexSet for HasVertexLiesPositive with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for HasVertexLiesPositive with fn successors(
  _self,
  _v,
) {
  Iter::empty()
}

///|
pub impl @alga.VertexSet for HasVertexLiesPositive with fn has_vertex(_self, _v) {
  true
}

///|
pub impl @alga.DirectedGraph for HasVertexLiesPositive

///|
pub impl @alga.DirectedGraph for HasVertexLies

///|
test "negative: Law C — has_vertex returns true for absent vertex flagged" {
  // has_vertex always returns true — must be flagged on synthetic outside values.
  let v = @alga.check_conformance(HasVertexLiesPositive::{  })
  assert_true(has_violation(v, ["Law C", "true"]))
}

///|
struct EachVertexWrong {}

///|
pub impl @alga.VertexSet for EachVertexWrong with fn iter(_self) {
  [1, 2, 3].iter()
}

///|
pub impl @alga.Successors for EachVertexWrong with fn successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.VertexSet for EachVertexWrong with fn each_vertex(_self, f) {
  // Intentionally drops vertex 3.
  f(1)
  f(2)
}

///|
pub impl @alga.DirectedGraph for EachVertexWrong

///|
test "negative: Law F — each_vertex override disagrees with iter" {
  let v = @alga.check_conformance(EachVertexWrong::{  })
  assert_true(has_violation(v, ["Law F", "each_vertex"]))
}

///|
struct EachSuccessorWrong {}

///|
pub impl @alga.VertexSet for EachSuccessorWrong with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for EachSuccessorWrong with fn successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.Successors for EachSuccessorWrong with fn each_successor(
  _self,
  _v,
  _f,
) {
  // Intentionally visits nothing even when successors(1) = [2].
  ()
}

///|
pub impl @alga.DirectedGraph for EachSuccessorWrong

///|
test "negative: Law F — each_successor override disagrees with successors" {
  let v = @alga.check_conformance(EachSuccessorWrong::{  })
  assert_true(has_violation(v, ["Law F", "each_successor"]))
}

///|
struct AsymmetricPred {}

///|
pub impl @alga.VertexSet for AsymmetricPred with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for AsymmetricPred with fn successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.Predecessors for AsymmetricPred with fn predecessors(_self, _v) {
  // Always empty — breaks symmetry (2 has 1 as a real predecessor).
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for AsymmetricPred

///|
test "negative: Law G — asymmetric predecessors flagged" {
  let v = @alga.check_predecessors_conformance(AsymmetricPred::{  })
  assert_true(has_violation(v, ["Law G"]))
}

///|
struct DupPred {}

///|
pub impl @alga.VertexSet for DupPred with fn iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.Successors for DupPred with fn successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.Predecessors for DupPred with fn predecessors(_self, v) {
  if v == 2 {
    [1, 1].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.DirectedGraph for DupPred

///|
test "negative: Law E' — duplicate predecessor flagged" {
  let v = @alga.check_predecessors_conformance(DupPred::{  })
  assert_true(has_violation(v, ["Law E'"]))
}

///|
/// A type that only implements `Successors` (no vertex enumeration).
/// Proves that `reachable`, `outdegree`, `dfs_fold`, and `bfs_fold`
/// work on successors-only graphs.
struct SuccessorsOnly {
  edges : Map[Int, Array[Int]]
}

///|
pub impl @alga.Successors for SuccessorsOnly with fn successors(self, v) {
  match self.edges.get(v) {
    Some(s) => s.iter()
    None => Iter::empty()
  }
}

///|
test "Successors-only: reachable works without VertexSet" {
  // 0 → 1 → 2 → 3
  let g = SuccessorsOnly::{
    edges: Map([(0, [1]), (1, [2]), (2, [3]), (3, [])]),
  }
  let r = @alga.reachable(g, 0)
  @test.assert_eq(r.length(), 4)
}

///|
test "Successors-only: dfs_fold works without VertexSet" {
  let g = SuccessorsOnly::{
    edges: Map([(0, [1, 2]), (1, [3]), (2, [3]), (3, [])]),
  }
  let visited : Array[Int] = @alga.dfs_fold(g, 0, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  @test.assert_eq(visited.length(), 4)
}

///|
test "Successors-only: bfs_fold works without VertexSet" {
  let g = SuccessorsOnly::{
    edges: Map([(0, [1, 2]), (1, [3]), (2, [3]), (3, [])]),
  }
  let visited : Array[Int] = @alga.bfs_fold(g, 0, [], fn(arr : Array[Int], v) {
    arr.push(v)
    (arr, true)
  })
  @test.assert_eq(visited.length(), 4)
}

///|
test "Successors-only: outdegree works without VertexSet" {
  let g = SuccessorsOnly::{
    edges: Map([(0, [1, 2]), (1, [3]), (2, []), (3, [])]),
  }
  @test.assert_eq(@alga.outdegree(g, 0), 2)
  @test.assert_eq(@alga.outdegree(g, 3), 0)
}
