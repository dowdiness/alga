///|
/// # Breadth-First Search (BFS)
///
/// BFS explores a graph level by level — first all vertices at distance 1
/// from the start, then distance 2, etc. This gives the shortest-path
/// property: the first time BFS visits a vertex, it has found the shortest
/// path (in number of edges) from the start.
///
/// ## Implementation: array-based queue
///
/// Uses an `Array` as a FIFO queue with a `head` index pointer.
/// Dequeue is O(1) (just increment `head`). The array grows but is never
/// compacted — acceptable since BFS visits each vertex at most once,
/// so the queue never exceeds V entries.
///
/// ## BFS vs DFS
///
/// - BFS gives shortest paths and level-order traversal
/// - DFS gives deeper exploration first, useful for topological sort
/// - Both are O(V + E) time and O(V) space
/// - BFS uses a queue (FIFO), DFS uses a stack (LIFO)
///
/// BFS is generally preferred for "how far is X from Y" questions,
/// while DFS is preferred for "is X reachable from Y" and structural
/// decomposition (SCC, topological sort).

///|
/// BFS fold over vertices reachable from `start`.
///
/// Same interface as `dfs_fold` but visits vertices in breadth-first
/// (level) order. Vertices at distance d from `start` are all visited
/// before any vertex at distance d+1.
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
pub fn[G : DirectedGraph, Acc] bfs_fold(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let queue : Array[Int] = [start]
  visited[start] = true
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    G::each_successor(graph, v, fn(w) {
      if visited.get(w) != Some(true) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}

///|
/// Multi-source BFS fold over vertices reachable from any vertex in `starts`.
///
/// Seeds the BFS queue with all start vertices instead of one, enabling
/// frontier-based traversal. This is the natural fit for problems where
/// traversal begins from a SET of vertices rather than a single root —
/// for example, CRDT event-graph-walkers that walk forward from a set
/// of frontier LVs, or multi-root dependency resolution.
///
/// ## Why multi-source instead of looping single-source?
///
/// Calling `bfs_fold` in a loop for each start would revisit vertices
/// reachable from multiple starts. Multi-source BFS visits each vertex
/// at most once across ALL starts, giving true O(V+E) for the union.
///
/// ## Seeding
///
/// - Invalid starts (not in the graph) are silently skipped via `has_vertex`
/// - Duplicate starts are deduplicated before traversal begins
/// - Starts are enqueued in input order — `starts[0]` is visited first
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
/// Seed validation calls `has_vertex` — override it for O(1) on custom types.
pub fn[G : DirectedGraph, Acc] bfs_fold_multi(
  graph : G,
  starts : Array[Int],
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let queue : Array[Int] = []
  for s in starts {
    if !visited.contains(s) && G::has_vertex(graph, s) {
      visited[s] = true
      queue.push(s)
    }
  }
  let mut acc = init
  let mut head = 0
  while head < queue.length() {
    let v = queue[head]
    head = head + 1
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    G::each_successor(graph, v, fn(w) {
      if !visited.contains(w) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}
