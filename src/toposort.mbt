///|
/// # Topological Sort (Kahn's Algorithm)
///
/// A topological ordering of a directed acyclic graph (DAG) is a linear
/// ordering of vertices such that for every edge u → v, u comes before v.
/// If the graph has a cycle, no topological ordering exists.
///
/// ## Algorithm: Kahn (1962)
///
/// 1. Compute in-degree (number of incoming edges) for each vertex.
/// 2. Enqueue all vertices with in-degree 0 (no dependencies).
/// 3. Repeatedly dequeue a vertex, add it to the result, and decrement
///    the in-degree of all its successors. When a successor's in-degree
///    reaches 0, enqueue it.
/// 4. If the result contains all vertices, return it. Otherwise, the
///    remaining vertices form a cycle — return None.
///
/// This is equivalent to repeatedly removing "ready" nodes — nodes with
/// no unsatisfied dependencies. It's the same principle behind build
/// systems (Make), package managers (dependency resolution), and
/// spreadsheet recalculation order.
///
/// ## Subset variant
///
/// `toposort_subset` sorts only a given subset of vertices, considering
/// only edges in the induced subgraph (both endpoints in the subset).
/// Scales with the subset size, not the full graph.
///
/// ## Cycle detection
///
/// Kahn's algorithm naturally detects cycles: if the result is shorter
/// than the vertex count, some vertices could never reach in-degree 0
/// because they're in a cycle. `has_cycle` is simply
/// `toposort(graph) is None`.
///
/// Time: O(V + E). Space: O(V).

///|
/// Topological sort via Kahn's algorithm.
/// Returns `Some(ordering)` for DAGs, `None` if the graph has a cycle.
///
/// **Warning:** Self-loops (edges v -> v) are treated as cycles and cause
/// this function to return `None`. If your graph may contain self-loops
/// that you want to ignore, call `remove_self_loops()` first.
pub fn[G : DirectedGraph] toposort(graph : G) -> Array[Int]? {
  // Step 1: Compute in-degrees
  let in_degree : Map[Int, Int] = Map::new()
  G::for_each_vertex(graph, fn(v) { in_degree[v] = 0 })
  G::for_each_vertex(graph, fn(v) {
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d + 1
    })
  })
  // Step 2: Seed queue with zero-in-degree vertices
  let queue : Array[Int] = []
  for v, d in in_degree {
    if d == 0 {
      queue.push(v)
    }
  }
  // Step 3: Process queue, building topological order
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d - 1
      if d - 1 == 0 {
        queue.push(w)
      }
    })
  }
  // Step 4: Check completeness — incomplete means a cycle exists
  let vc = G::vertex_count(graph)
  if result.length() == vc {
    Some(result)
  } else {
    None
  }
}

///|
/// Returns true if the graph contains a directed cycle.
/// A self-loop (v → v) counts as a cycle.
pub fn[G : DirectedGraph] has_cycle(graph : G) -> Bool {
  toposort(graph) is None
}

///|
/// # Topological Levels
///
/// Computes the distance from the nearest source (zero-in-degree vertex)
/// for every vertex in a DAG. A source gets level 0, its successors get
/// level 1, and so on — each vertex's level is the length of the longest
/// path from any source to it.
///
/// ## Why this is useful
///
/// Topological levels enable **glitch-free reactive propagation**: when
/// signals are pushed in ascending level order, every node sees all its
/// dependencies before it fires. This is exactly the level-sorted BFS
/// schedule used by reactive frameworks like incr.
///
/// ## Cycle detection
///
/// Like `toposort`, this is a modified Kahn's algorithm. If not all
/// vertices are processed, a cycle exists and the function returns `None`.
/// Self-loops (v → v) count as cycles.
///
/// ## Return value
///
/// `Map[Int, Int]?` mapping each vertex to its level, or `None` if the
/// graph has a cycle. The map preserves the original vertex IDs (works
/// for both sparse `AdjacencyMap` and dense `DenseGraph` IDs).
///
/// Time: O(V + E). Space: O(V).
pub fn[G : DirectedGraph] topo_levels(graph : G) -> Map[Int, Int]? {
  // Step 1: Compute in-degrees
  let in_degree : Map[Int, Int] = Map::new()
  let vertices : Array[Int] = []
  G::for_each_vertex(graph, fn(v) {
    in_degree[v] = 0
    vertices.push(v)
  })
  G::for_each_vertex(graph, fn(v) {
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d + 1
    })
  })
  // Step 2: Seed queue with sources (in-degree 0) at level 0
  let levels : Map[Int, Int] = Map::new()
  let queue : Array[Int] = []
  for v in vertices {
    if in_degree.get(v) == Some(0) {
      levels[v] = 0
      queue.push(v)
    }
  }
  // Step 3: BFS — propagate levels through the graph
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let v_level = match levels.get(v) {
      Some(l) => l
      None => 0
    }
    G::for_each_successor(graph, v, fn(w) {
      let d = match in_degree.get(w) {
        Some(n) => n
        None => 0
      }
      in_degree[w] = d - 1
      // Track the max level from any predecessor — ensures the level
      // reflects the longest path from any source, which is required
      // for glitch-free scheduling (all predecessors at lower levels).
      let current_level = match levels.get(w) {
        Some(l) => l
        None => 0
      }
      let new_level = v_level + 1
      if new_level > current_level {
        levels[w] = new_level
      }
      if d - 1 == 0 {
        queue.push(w)
      }
    })
  }
  // Step 4: Check completeness — incomplete means a cycle exists
  if queue.length() != vertices.length() {
    return None
  }
  Some(levels)
}

///|
/// Topological sort over the induced subgraph of `vertices`.
///
/// Only edges where both endpoints are in `vertices` are considered.
/// Returns `Some(ordering)` if the induced subgraph is a DAG, `None`
/// if it contains a cycle. Returns `Some([])` for an empty vertex set.
/// Duplicate vertices in the input are handled correctly.
///
/// **Input validation:** Invalid vertex IDs (not present in the graph)
/// are silently filtered out rather than causing errors or panics.
/// This makes `toposort_subset` composable — callers don't need to
/// pre-validate their vertex list against the graph, which matters
/// when the list may lag behind graph mutations. The filtering cost
/// is O(k) with O(1) `has_vertex` overrides (AdjacencyMap, DenseGraph),
/// or O(k * V) for types using the O(V) default.
///
/// Time: O(V_sub + E_sub). Space: O(V_sub).
pub fn[G : DirectedGraph] toposort_subset(
  graph : G,
  vertices : Array[Int],
) -> Array[Int]? {
  // Build membership set and deduplicated vertex list (preserves input order).
  // has_vertex filters out IDs not in the graph — prevents panics on
  // DenseGraph (out-of-bounds) and inconsistent results on AdjacencyMap
  // (unknown IDs treated as isolated vertices with in-degree 0).
  let subset : @hashset.HashSet[Int] = @hashset.new()
  let unique : Array[Int] = []
  for v in vertices {
    if !subset.contains(v) && G::has_vertex(graph, v) {
      subset.add(v)
      unique.push(v)
    }
  }
  let n = unique.length()
  if n == 0 {
    return Some([])
  }
  // Compute in-degrees within the induced subgraph
  let in_degree : @hashmap.HashMap[Int, Int] = @hashmap.new()
  for v in unique {
    G::for_each_successor(graph, v, fn(w) {
      if subset.contains(w) {
        match in_degree.get(w) {
          Some(d) => in_degree[w] = d + 1
          None => in_degree[w] = 1
        }
      }
    })
  }
  // Seed queue with zero-in-degree subset vertices (input order)
  let queue : Array[Int] = []
  for v in unique {
    if !in_degree.contains(v) {
      queue.push(v)
    }
  }
  // Process queue
  let result : Array[Int] = []
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    result.push(v)
    G::for_each_successor(graph, v, fn(w) {
      if subset.contains(w) {
        match in_degree.get(w) {
          Some(d) => {
            in_degree[w] = d - 1
            if d - 1 == 0 {
              queue.push(w)
            }
          }
          None => ()
        }
      }
    })
  }
  if result.length() == n {
    Some(result)
  } else {
    None
  }
}
