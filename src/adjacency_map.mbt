///|
/// # AdjacencyMap — the canonical graph representation
///
/// Stores a directed graph as `Map[Int, Array[Int]]` where each key is a
/// vertex and its value is the list of successor vertices. This is the
/// standard "adjacency list" representation used in most graph textbooks.
///
/// ## Key invariant
///
/// Every vertex that appears as an edge target also exists as a key in the
/// map (with an empty successor list if it has no outgoing edges). This
/// means `adjacency.keys() == vertex_set` — you never have a "dangling"
/// edge pointing to a vertex that doesn't exist in the map.
///
/// ## Algebraic graph operations
///
/// AdjacencyMap supports the four algebraic graph operations from
/// Mokhov's "Algebraic Graphs with Class" (2017):
///
/// - `empty()` — the empty graph (no vertices, no edges)
/// - `vertex(v)` — a single vertex with no edges
/// - `overlay(g1, g2)` — union of vertices and edges
/// - `connect(g1, g2)` — overlay + all edges from g1's vertices to g2's
///
/// These satisfy the algebraic graph axioms (overlay is commutative and
/// associative, connect is associative, connect distributes over overlay).
///
/// ## Performance characteristics
///
/// | Operation      | Time complexity |
/// |----------------|-----------------|
/// | from_edges     | O(E) amortized  |
/// | has_vertex     | O(1)            |
/// | has_edge       | O(degree)       |
/// | overlay        | O(V + E)        |
/// | connect        | O(V1 * V2 + E)  |
/// | transpose      | O(V + E)        |
/// | vertex_count   | O(1)            |
/// | edge_count     | O(V)            |
pub struct AdjacencyMap {
  adjacency : Map[Int, Array[Int]]
}

///|
/// The empty graph: no vertices, no edges.
/// Identity element for both overlay and connect.
pub fn AdjacencyMap::empty() -> AdjacencyMap {
  { adjacency: Map::new() }
}

///|
/// A graph with a single vertex and no edges.
pub fn AdjacencyMap::vertex(v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  m[v] = []
  { adjacency: m }
}

///|
/// A graph with a single directed edge u -> v.
/// Both u and v are added as vertices (maintaining the key invariant).
pub fn AdjacencyMap::edge(u : Int, v : Int) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  m[u] = [v]
  if u != v {
    m[v] = []
  }
  { adjacency: m }
}

///|
/// Build a graph from an array of directed edges.
/// Duplicate edges are silently ignored. All endpoints are registered
/// as vertices (maintaining the key invariant).
///
/// Uses `HashSet` internally for O(1) duplicate edge detection.
pub fn AdjacencyMap::from_edges(edges : Array[(Int, Int)]) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let seen : Map[Int, @hashset.HashSet[Int]] = Map::new()
  for edge in edges {
    let u = edge.0
    let v = edge.1
    match seen.get(u) {
      Some(set) =>
        if !set.contains(v) {
          set.add(v)
          match m.get(u) {
            Some(arr) => arr.push(v)
            None => m[u] = [v]
          }
        }
      None => {
        let set : @hashset.HashSet[Int] = @hashset.new()
        set.add(v)
        seen[u] = set
        m[u] = [v]
      }
    }
    if !m.contains(v) {
      m[v] = []
    }
  }
  { adjacency: m }
}

///|
/// Overlay: union of two graphs' vertices and edges.
///
/// `overlay(G1, G2)` contains every vertex and edge from both G1 and G2.
/// This is the graph analogue of set union. Overlay is commutative and
/// associative: `overlay(a, b) == overlay(b, a)`.
///
/// Uses `HashSet` internally for O(1) duplicate edge detection.
pub fn AdjacencyMap::overlay(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let seen : Map[Int, @hashset.HashSet[Int]] = Map::new()
  for k, v in self.adjacency {
    let arr = v.copy()
    m[k] = arr
    let set : @hashset.HashSet[Int] = @hashset.new()
    for elem in arr {
      set.add(elem)
    }
    seen[k] = set
  }
  for k, v in other.adjacency {
    match m.get(k) {
      Some(existing) => {
        let set = match seen.get(k) {
          Some(s) => s
          None => {
            let s : @hashset.HashSet[Int] = @hashset.new()
            seen[k] = s
            s
          }
        }
        for elem in v {
          if !set.contains(elem) {
            set.add(elem)
            existing.push(elem)
          }
        }
      }
      None => {
        m[k] = v.copy()
        let set : @hashset.HashSet[Int] = @hashset.new()
        for elem in v {
          set.add(elem)
        }
        seen[k] = set
      }
    }
  }
  { adjacency: m }
}

///|
/// Connect: overlay + all cross-edges from self's vertices to other's.
///
/// `connect(G1, G2)` contains everything from `overlay(G1, G2)` plus
/// a directed edge from every vertex in G1 to every vertex in G2.
/// Connect is associative but NOT commutative.
///
/// This is the key operation that makes algebraic graph construction
/// possible — `connect(vertex(1), vertex(2))` creates the edge 1 -> 2.
///
/// Uses `HashSet` internally for O(1) duplicate edge detection.
pub fn AdjacencyMap::connect(
  self : AdjacencyMap,
  other : AdjacencyMap,
) -> AdjacencyMap {
  let base = self.overlay(other)
  let m = base.adjacency
  let other_vertices : Array[Int] = []
  for k, _ in other.adjacency {
    other_vertices.push(k)
  }
  for u, _ in self.adjacency {
    let current = match m.get(u) {
      Some(s) => s
      None => []
    }
    let set : @hashset.HashSet[Int] = @hashset.new()
    for elem in current {
      set.add(elem)
    }
    for ov in other_vertices {
      if !set.contains(ov) {
        set.add(ov)
        current.push(ov)
      }
    }
    m[u] = current
  }
  { adjacency: m }
}

///|
/// All vertices as an array.
pub fn AdjacencyMap::vertex_list(self : AdjacencyMap) -> Array[Int] {
  let result : Array[Int] = []
  for k, _ in self.adjacency {
    result.push(k)
  }
  result
}

///|
/// All edges as (source, target) pairs.
pub fn AdjacencyMap::edge_list(self : AdjacencyMap) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for u, succs in self.adjacency {
    for v in succs {
      result.push((u, v))
    }
  }
  result
}

///|
/// Successor vertices of v (vertices reachable by one edge from v).
pub fn AdjacencyMap::successors(self : AdjacencyMap, v : Int) -> Array[Int] {
  match self.adjacency.get(v) {
    Some(s) => s.copy()
    None => []
  }
}

///|
pub fn AdjacencyMap::has_vertex(self : AdjacencyMap, v : Int) -> Bool {
  self.adjacency.contains(v)
}

///|
pub fn AdjacencyMap::has_edge(self : AdjacencyMap, u : Int, v : Int) -> Bool {
  match self.adjacency.get(u) {
    Some(s) => s.contains(v)
    None => false
  }
}

///|
pub fn AdjacencyMap::vertex_count(self : AdjacencyMap) -> Int {
  self.adjacency.length()
}

///|
/// Count all edges. O(V) — sums successor list lengths.
pub fn AdjacencyMap::edge_count(self : AdjacencyMap) -> Int {
  for _, v in self.adjacency; count = 0 {
    continue count + v.length()
  } nobreak {
    count
  }
}

///|
/// Reverse all edge directions. Vertex set is unchanged.
///
/// Transpose is essential for Kosaraju's SCC algorithm (Phase 2 runs
/// DFS on the transposed graph) and for computing predecessor queries.
///
/// Uses `HashSet` internally for O(1) duplicate edge detection.
pub fn AdjacencyMap::transpose(self : AdjacencyMap) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  let seen : Map[Int, @hashset.HashSet[Int]] = Map::new()
  for k, _ in self.adjacency {
    if !m.contains(k) {
      m[k] = []
      seen[k] = @hashset.new()
    }
  }
  for u, succs in self.adjacency {
    for v in succs {
      let set = match seen.get(v) {
        Some(s) => s
        None => {
          let s : @hashset.HashSet[Int] = @hashset.new()
          seen[v] = s
          s
        }
      }
      if !set.contains(u) {
        set.add(u)
        match m.get(v) {
          Some(arr) => arr.push(u)
          None => m[v] = [u]
        }
      }
    }
  }
  { adjacency: m }
}

///|
/// Remove all self-loops (edges v -> v) from the graph.
/// Returns a new graph with the same vertex set but no self-loops.
pub fn AdjacencyMap::remove_self_loops(self : AdjacencyMap) -> AdjacencyMap {
  let m : Map[Int, Array[Int]] = Map::new()
  for k, succs in self.adjacency {
    let filtered : Array[Int] = []
    for v in succs {
      if v != k {
        filtered.push(v)
      }
    }
    m[k] = filtered
  }
  { adjacency: m }
}

///|
/// Show implementation for AdjacencyMap.
/// Format: `AdjacencyMap({1: [2, 3], 2: []})`
pub impl Show for AdjacencyMap with output(self, logger) {
  logger.write_string("AdjacencyMap({")
  let keys : Array[Int] = []
  for k, _ in self.adjacency {
    keys.push(k)
  }
  keys.sort()
  for i, k in keys {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string(k.to_string())
    logger.write_string(": [")
    let succs = match self.adjacency.get(k) {
      Some(s) => s
      None => []
    }
    let sorted = succs.copy()
    sorted.sort()
    for j, v in sorted {
      if j > 0 {
        logger.write_string(", ")
      }
      logger.write_string(v.to_string())
    }
    logger.write_string("]")
  }
  logger.write_string("})")
}

///|
/// Debug implementation for AdjacencyMap.
/// Produces structured Repr for inspect/debugging tools.
pub impl Debug for AdjacencyMap with to_repr(self) {
  let entries : Array[(@debug.Repr, @debug.Repr)] = []
  let keys : Array[Int] = []
  for k, _ in self.adjacency {
    keys.push(k)
  }
  keys.sort()
  for k in keys {
    let succs = match self.adjacency.get(k) {
      Some(s) => s
      None => []
    }
    let sorted = succs.copy()
    sorted.sort()
    entries.push(
      (
        @debug.to_repr(k),
        @debug.Repr::array(sorted.map(fn(v) { @debug.to_repr(v) })),
      ),
    )
  }
  @debug.Repr::opaque_("AdjacencyMap", @debug.Repr::map(entries))
}

///|
/// Eq implementation for AdjacencyMap.
/// Two graphs are equal if they have the same vertices and edges.
/// Successor arrays are sorted before comparison since order may differ.
pub impl Eq for AdjacencyMap with equal(self, other) -> Bool {
  if self.adjacency.length() != other.adjacency.length() {
    return false
  }
  for k, v in self.adjacency {
    match other.adjacency.get(k) {
      None => return false
      Some(other_v) => {
        if v.length() != other_v.length() {
          return false
        }
        let sorted_self = v.copy()
        sorted_self.sort()
        let sorted_other = other_v.copy()
        sorted_other.sort()
        for i = 0; i < sorted_self.length(); i = i + 1 {
          if sorted_self[i] != sorted_other[i] {
            return false
          }
        }
      }
    }
  }
  true
}

///|
/// DirectedGraph trait implementation — delegates to the adjacency map.
pub impl DirectedGraph for AdjacencyMap with vertex_count(self) {
  self.adjacency.length()
}

///|
pub impl DirectedGraph for AdjacencyMap with for_each_vertex(self, f) {
  for k, _ in self.adjacency {
    f(k)
  }
}

///|
pub impl DirectedGraph for AdjacencyMap with for_each_successor(self, v, f) {
  match self.adjacency.get(v) {
    Some(s) =>
      for x in s {
        f(x)
      }
    None => ()
  }
}
