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
pub impl @alga.DirectedGraph for DupIter with iter(_self) {
  [1, 1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for DupIter with successors(_self, _v) {
  Iter::empty()
}

///|
struct DanglingSucc {}

///|
pub impl @alga.DirectedGraph for DanglingSucc with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for DanglingSucc with successors(_self, v) {
  if v == 1 {
    [99].iter()
  } else {
    Iter::empty()
  }
}

///|
struct DupSucc {}

///|
pub impl @alga.DirectedGraph for DupSucc with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for DupSucc with successors(_self, v) {
  if v == 1 {
    [2, 2].iter()
  } else {
    Iter::empty()
  }
}

///|
struct VertexCountLies {}

///|
pub impl @alga.DirectedGraph for VertexCountLies with iter(_self) {
  [1, 2, 3].iter()
}

///|
pub impl @alga.DirectedGraph for VertexCountLies with successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for VertexCountLies with vertex_count(_self) {
  7
}

///|
struct HasVertexLies {}

///|
pub impl @alga.DirectedGraph for HasVertexLies with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for HasVertexLies with successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for HasVertexLies with has_vertex(_self, _v) {
  false
}

///|
test "positive: AdjacencyMap conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  assert_eq(@alga.check_conformance(g), [])
}

///|
test "positive: AdjacencyMap with Predecessors conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1), (1, 3)])
  assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: DenseGraph conforms" {
  let g = @alga.DenseGraph::from_edges(4, [(0, 1), (1, 2), (2, 0), (2, 3)])
  assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: Reversed conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  assert_eq(@alga.check_predecessors_conformance(@alga.reversed(g)), [])
}

///|
test "positive: empty graph conforms" {
  let g : @alga.AdjacencyMap = @alga.AdjacencyMap::empty()
  assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: single vertex conforms" {
  let g = @alga.AdjacencyMap::vertex(42)
  assert_eq(@alga.check_predecessors_conformance(g), [])
}

///|
test "positive: self-loop conforms" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  assert_eq(@alga.check_predecessors_conformance(g), [])
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
pub impl @alga.DirectedGraph for HasVertexLiesPositive with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for HasVertexLiesPositive with successors(
  _self,
  _v,
) {
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for HasVertexLiesPositive with has_vertex(
  _self,
  _v,
) {
  true
}

///|
test "negative: Law C — has_vertex returns true for absent vertex flagged" {
  // has_vertex always returns true — must be flagged on synthetic outside values.
  let v = @alga.check_conformance(HasVertexLiesPositive::{  })
  assert_true(has_violation(v, ["Law C", "true"]))
}

///|
struct EachVertexWrong {}

///|
pub impl @alga.DirectedGraph for EachVertexWrong with iter(_self) {
  [1, 2, 3].iter()
}

///|
pub impl @alga.DirectedGraph for EachVertexWrong with successors(_self, _v) {
  Iter::empty()
}

///|
pub impl @alga.DirectedGraph for EachVertexWrong with each_vertex(_self, f) {
  // Intentionally drops vertex 3.
  f(1)
  f(2)
}

///|
test "negative: Law F — each_vertex override disagrees with iter" {
  let v = @alga.check_conformance(EachVertexWrong::{  })
  assert_true(has_violation(v, ["Law F", "each_vertex"]))
}

///|
struct EachSuccessorWrong {}

///|
pub impl @alga.DirectedGraph for EachSuccessorWrong with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for EachSuccessorWrong with successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.DirectedGraph for EachSuccessorWrong with each_successor(
  _self,
  _v,
  _f,
) {
  // Intentionally visits nothing even when successors(1) = [2].
  ()
}

///|
test "negative: Law F — each_successor override disagrees with successors" {
  let v = @alga.check_conformance(EachSuccessorWrong::{  })
  assert_true(has_violation(v, ["Law F", "each_successor"]))
}

///|
struct AsymmetricPred {}

///|
pub impl @alga.DirectedGraph for AsymmetricPred with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for AsymmetricPred with successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.Predecessors for AsymmetricPred with predecessors(_self, _v) {
  // Always empty — breaks symmetry (2 has 1 as a real predecessor).
  Iter::empty()
}

///|
test "negative: Law G — asymmetric predecessors flagged" {
  let v = @alga.check_predecessors_conformance(AsymmetricPred::{  })
  assert_true(has_violation(v, ["Law G"]))
}

///|
struct DupPred {}

///|
pub impl @alga.DirectedGraph for DupPred with iter(_self) {
  [1, 2].iter()
}

///|
pub impl @alga.DirectedGraph for DupPred with successors(_self, v) {
  if v == 1 {
    [2].iter()
  } else {
    Iter::empty()
  }
}

///|
pub impl @alga.Predecessors for DupPred with predecessors(_self, v) {
  if v == 2 {
    [1, 1].iter()
  } else {
    Iter::empty()
  }
}

///|
test "negative: Law E' — duplicate predecessor flagged" {
  let v = @alga.check_predecessors_conformance(DupPred::{  })
  assert_true(has_violation(v, ["Law E'"]))
}
