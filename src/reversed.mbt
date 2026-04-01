///|
/// # Reversed — zero-cost reverse-direction graph view
///
/// Wraps any graph that implements `DirectedGraph + Predecessors` and
/// swaps the direction of all edge queries. `successors` on the reversed
/// graph returns `predecessors` on the original, and vice versa.
///
/// ## Properties
///
/// - **Lightweight**: holds the original graph value. For alga's types
///   (AdjacencyMap, DenseGraph), this is a shallow handle copy.
/// - **Involution**: `Reversed(Reversed(g))` produces the same traversal as `g`.
/// - **Composable**: implements `DirectedGraph + Predecessors`, works with
///   all algorithms: `dfs_events`, `reachable`, `toposort`, `tarjan_scc`, etc.
pub struct Reversed[G] {
  graph : G
}

///|
pub fn[G : DirectedGraph + Predecessors] reversed(graph : G) -> Reversed[G] {
  { graph, }
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with iter(
  self,
) {
  G::iter(self.graph)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with successors(
  self,
  v,
) {
  G::predecessors(self.graph, v)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with has_vertex(
  self,
  v,
) {
  G::has_vertex(self.graph, v)
}

///|
pub impl[G : DirectedGraph + Predecessors] DirectedGraph for Reversed[G] with vertex_count(
  self,
) {
  G::vertex_count(self.graph)
}

///|
pub impl[G : DirectedGraph + Predecessors] Predecessors for Reversed[G] with predecessors(
  self,
  v,
) {
  G::successors(self.graph, v)
}
