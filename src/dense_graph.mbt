///|
/// # DenseGraph — flat adjacency representation for dense vertex IDs
///
/// Stores a directed graph as `Array[Array[Int]]` where vertex v's
/// successors are at `successors[v]`. Requires dense vertex IDs in
/// range 0..vertex_count-1.
///
/// ## When to use
///
/// Use `DenseGraph` when:
/// - Vertex IDs are integers in 0..n-1 (common for internal algorithms)
/// - You need maximum traversal performance (8–23x faster than AdjacencyMap)
/// - You're running algorithms repeatedly on the same graph
///
/// Use `AdjacencyMap` when:
/// - Vertex IDs are sparse or non-contiguous
/// - You need algebraic graph operations (overlay, connect)
/// - You're building graphs via the `GraphSym` construction layer
///
/// ## Conversion
///
/// `AdjacencyMap` → `DenseGraph` via `DenseGraph::from_adjacency_map`
/// (requires dense vertex IDs starting from 0).
///
/// ## Performance characteristics
///
/// | Operation        | AdjacencyMap    | DenseGraph      |
/// |------------------|-----------------|-----------------|
/// | successor lookup | O(log V) (Map)  | O(1) (Array)    |
/// | transpose        | O(1)            | O(1)            |
/// | DFS reachable    | ~94 µs (1000V)  | ~7 µs (1000V)   |
/// | SCC              | ~460 µs (1000V) | ~50 µs (1000V)  |
pub(all) struct DenseGraph {
  successors : Array[Array[Int]]
  predecessors : Array[Array[Int]]
}

///|
/// Number of vertices (0..n-1).
pub fn DenseGraph::vertex_count(self : DenseGraph) -> Int {
  self.successors.length()
}

///|
/// Build from edge list. Duplicate edges are silently ignored.
///
/// Aborts if any vertex in the edge list is outside 0..vertex_count-1.
pub fn DenseGraph::from_edges(
  vertex_count : Int,
  edges : Array[(Int, Int)],
) -> DenseGraph {
  let succs : Array[Array[Int]] = Array::makei(vertex_count, fn(_i) { [] })
  let preds : Array[Array[Int]] = Array::makei(vertex_count, fn(_i) { [] })
  let seen : Array[@hashset.HashSet[Int]] = Array::makei(vertex_count, fn(_i) {
    @hashset.new()
  })
  for edge in edges {
    let u = edge.0
    let v = edge.1
    guard u >= 0 && u < vertex_count && v >= 0 && v < vertex_count else {
      abort(
        "DenseGraph::from_edges: vertex out of range 0..\{vertex_count - 1}: edge (\{u}, \{v})",
      )
    }
    if !seen[u].contains(v) {
      seen[u].add(v)
      succs[u].push(v)
      preds[v].push(u)
    }
  }
  { successors: succs, predecessors: preds }
}

///|
/// Convert from AdjacencyMap.
///
/// Aborts if the AdjacencyMap contains vertex IDs outside 0..n-1
/// (where n is the vertex count). Use only with AdjacencyMaps that
/// have dense, zero-based vertex IDs.
pub fn DenseGraph::from_adjacency_map(am : AdjacencyMap) -> DenseGraph {
  let n = am.vertex_count()
  let succs : Array[Array[Int]] = Array::makei(n, fn(_i) { [] })
  let preds : Array[Array[Int]] = Array::makei(n, fn(_i) { [] })
  for v, s in am.adjacency {
    guard v >= 0 && v < n else {
      abort(
        "DenseGraph::from_adjacency_map: vertex \{v} out of range 0..\{n - 1}",
      )
    }
    succs[v] = s.copy()
    for w in s {
      guard w >= 0 && w < n else {
        abort(
          "DenseGraph::from_adjacency_map: successor \{w} of vertex \{v} out of range 0..\{n - 1}",
        )
      }
      preds[w].push(v)
    }
  }
  { successors: succs, predecessors: preds }
}

///|
/// Reverse all edge directions. O(1) — swaps successor and predecessor arrays.
pub fn DenseGraph::transpose(self : DenseGraph) -> DenseGraph {
  { successors: self.predecessors, predecessors: self.successors }
}

///|
pub fn DenseGraph::has_vertex(self : DenseGraph, v : Int) -> Bool {
  v >= 0 && v < self.successors.length()
}

///|
pub fn DenseGraph::has_edge(self : DenseGraph, u : Int, v : Int) -> Bool {
  if u < 0 || u >= self.successors.length() {
    return false
  }
  self.successors[u].contains(v)
}

///|
pub fn DenseGraph::edge_count(self : DenseGraph) -> Int {
  for succs in self.successors; count = 0 {
    continue count + succs.length()
  } nobreak {
    count
  }
}

///|
/// Show implementation for DenseGraph.
/// Format: `DenseGraph(3 vertices, [0 -> [1, 2], 1 -> [2]])`
pub impl Show for DenseGraph with output(self, logger) {
  let n = self.successors.length()
  logger.write_string("DenseGraph(")
  logger.write_string(n.to_string())
  logger.write_string(" vertices, [")
  let mut first = true
  for v = 0; v < n; v = v + 1 {
    let succs = self.successors[v]
    if succs.length() > 0 {
      if !first {
        logger.write_string(", ")
      }
      first = false
      logger.write_string(v.to_string())
      logger.write_string(" -> [")
      for j, w in succs {
        if j > 0 {
          logger.write_string(", ")
        }
        logger.write_string(w.to_string())
      }
      logger.write_string("]")
    }
  }
  logger.write_string("])")
}

///|
/// Debug implementation for DenseGraph.
/// Produces structured Repr showing vertex count and edges.
pub impl Debug for DenseGraph with to_repr(self) {
  let fields : Map[String, @debug.Repr] = Map::new()
  fields["vertex_count"] = @debug.to_repr(self.successors.length())
  let edges : Array[@debug.Repr] = []
  for v = 0; v < self.successors.length(); v = v + 1 {
    for w in self.successors[v] {
      edges.push(@debug.Repr::tuple([@debug.to_repr(v), @debug.to_repr(w)]))
    }
  }
  fields["edges"] = @debug.Repr::array(edges)
  @debug.Repr::opaque_("DenseGraph", @debug.Repr::record(fields))
}

///|
pub impl DirectedGraph for DenseGraph with iter(self) {
  (0).until(self.successors.length())
}

///|
/// O(1) override — array length, bypasses the O(V) default iteration.
pub impl DirectedGraph for DenseGraph with vertex_count(self) {
  self.successors.length()
}

///|
pub impl DirectedGraph for DenseGraph with successors(self, v) {
  if v >= 0 && v < self.successors.length() {
    self.successors[v].iter()
  } else {
    Iter::empty()
  }
}

///|
/// O(1) override — range check on dense 0..n-1 vertex IDs.
pub impl DirectedGraph for DenseGraph with has_vertex(self, v) {
  v >= 0 && v < self.successors.length()
}

///|
pub impl Predecessors for DenseGraph with predecessors(self, v) {
  if v >= 0 && v < self.predecessors.length() {
    self.predecessors[v].iter()
  } else {
    Iter::empty()
  }
}

// ============================================================
// Optimized algorithms — bypass trait dispatch + callbacks
// ============================================================

///|
/// DFS reachable with direct array access. No trait dispatch, no callbacks,
/// no per-vertex allocation. Allocates a fresh visited set per call.
///
/// Returns empty array if `start` is not a valid vertex.
///
/// For repeated calls on the same graph, use `reachable_with` to amortize
/// the visited-set allocation via generation counter.
pub fn DenseGraph::reachable(self : DenseGraph, start : Int) -> Array[Int] {
  let n = self.successors.length()
  if start < 0 || start >= n {
    return []
  }
  let visited = FixedArray::make(n, false)
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] {
      continue
    }
    visited[v] = true
    result.push(v)
    let succs = self.successors[v]
    for i in (succs.length() - 1)>=..0 {
      let w = succs[i]
      if !visited[w] {
        stack.push(w)
      }
    }
  }
  result
}

///|
/// DFS reachable with pre-allocated generation-counter visited set.
/// Amortizes O(V) init cost across repeated calls — each call is O(1)
/// reset (just bump `gen`) instead of O(V) zeroing.
///
/// Returns empty array if `start` is not a valid vertex.
///
/// **Important:** `gen` must be a fresh value on each call — never reuse
/// a previous `gen` value, and never pass `gen = 0` against a
/// zero-initialized buffer. The simplest pattern is to increment a
/// counter before each call:
///
/// ```
/// let visited = FixedArray::make(graph.vertex_count(), 0)
/// let mut gen = 0
/// // Each call reuses the same buffer:
/// gen = gen + 1
/// let r1 = graph.reachable_with(start1, visited, gen)
/// gen = gen + 1
/// let r2 = graph.reachable_with(start2, visited, gen)
/// ```
pub fn DenseGraph::reachable_with(
  self : DenseGraph,
  start : Int,
  visited : FixedArray[Int],
  gen : Int,
) -> Array[Int] {
  let n = self.successors.length()
  if start < 0 || start >= n {
    return []
  }
  let stack : Array[Int] = [start]
  let result : Array[Int] = []
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited[v] == gen {
      continue
    }
    visited[v] = gen
    result.push(v)
    let succs = self.successors[v]
    for i in (succs.length() - 1)>=..0 {
      let w = succs[i]
      if visited[w] != gen {
        stack.push(w)
      }
    }
  }
  result
}

///|
/// Topological sort with direct array access.
pub fn DenseGraph::toposort(self : DenseGraph) -> Array[Int]? {
  let n = self.successors.length()
  let in_degree = Array::make(n, 0)
  for u = 0; u < n; u = u + 1 {
    for v in self.successors[u] {
      in_degree[v] = in_degree[v] + 1
    }
  }
  let queue : Array[Int] = []
  for v = 0; v < n; v = v + 1 {
    if in_degree[v] == 0 {
      queue.push(v)
    }
  }
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    for w in self.successors[v] {
      in_degree[w] = in_degree[w] - 1
      if in_degree[w] == 0 {
        queue.push(w)
      }
    }
  }
  if result.length() == n {
    Some(result)
  } else {
    None
  }
}

///|
pub fn DenseGraph::has_cycle(self : DenseGraph) -> Bool {
  self.toposort() is None
}

///|
/// Strongly connected components via Kosaraju's algorithm.
/// Both DFS passes and transpose use direct array access.
pub fn DenseGraph::scc(self : DenseGraph) -> Array[Array[Int]] {
  let n = self.successors.length()
  let visited = FixedArray::make(n, false)
  let finish_order : Array[Int] = []
  // Pass 1: forward DFS — record finish order
  for root = 0; root < n; root = root + 1 {
    if visited[root] {
      continue
    }
    let stack : Array[(Int, Int)] = [(root, 0)]
    visited[root] = true
    while stack.length() > 0 {
      let top_idx = stack.length() - 1
      let v = stack[top_idx].0
      let si = stack[top_idx].1
      let succs = self.successors[v]
      if si < succs.length() {
        stack[top_idx] = (v, si + 1)
        let w = succs[si]
        if !visited[w] {
          visited[w] = true
          stack.push((w, 0))
        }
      } else {
        let _ = stack.unsafe_pop()
        finish_order.push(v)
      }
    }
  }
  // Pass 2: transpose (flat → flat)
  let transposed = self.transpose()
  // Pass 3: backward DFS in reverse finish order
  let visited2 = FixedArray::make(n, false)
  let components : Array[Array[Int]] = []
  for i in (finish_order.length() - 1)>=..0 {
    let root = finish_order[i]
    if visited2[root] {
      continue
    }
    let component : Array[Int] = []
    let stack : Array[Int] = [root]
    visited2[root] = true
    while stack.length() > 0 {
      let v = stack.unsafe_pop()
      component.push(v)
      let succs = transposed.successors[v]
      for j in (succs.length() - 1)>=..0 {
        let w = succs[j]
        if !visited2[w] {
          visited2[w] = true
          stack.push(w)
        }
      }
    }
    components.push(component)
  }
  components
}
