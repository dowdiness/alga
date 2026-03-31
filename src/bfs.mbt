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
    G::for_each_successor(graph, v, fn(w) {
      if visited.get(w) != Some(true) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}
