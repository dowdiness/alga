///|
/// # Reversed — zero-cost reverse-direction graph view
///
/// Wraps any graph and swaps the direction of all edge queries.
/// `successors` on the reversed graph returns `predecessors` on the
/// original, and vice versa.
///
/// ## Capabilities provided
///
/// - `VertexSet for Reversed[G]` when `G : VertexSet`
/// - `Successors for Reversed[G]` when `G : Predecessors`
/// - `Predecessors for Reversed[G]` when `G : Successors`
/// - `DirectedGraph for Reversed[G]` when `G : VertexSet + Predecessors`
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
pub fn[G] reversed(graph : G) -> Reversed[G] {
  { graph, }
}

///|
pub impl[G : VertexSet] VertexSet for Reversed[G] with fn iter(self) {
  G::iter(self.graph)
}

///|
pub impl[G : VertexSet] VertexSet for Reversed[G] with fn has_vertex(self, v) {
  G::has_vertex(self.graph, v)
}

///|
pub impl[G : VertexSet] VertexSet for Reversed[G] with fn vertex_count(self) {
  G::vertex_count(self.graph)
}

///|
pub impl[G : Predecessors] Successors for Reversed[G] with fn successors(
  self,
  v,
) {
  G::predecessors(self.graph, v)
}

///|
pub impl[G : VertexSet + Predecessors] DirectedGraph for Reversed[G]

///|
pub impl[G : Successors] Predecessors for Reversed[G] with fn predecessors(
  self,
  v,
) {
  G::successors(self.graph, v)
}
