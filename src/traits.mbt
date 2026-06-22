///|
/// # Observation layer — capability traits
///
/// The observation layer is split into two fine-grained capability traits
/// so that types that can follow edges but cannot enumerate all vertices
/// (implicit graphs, pure functions, infinite streams) can still run
/// local reachability and BFS/DFS from a known start.
///
/// - `VertexSet` — vertex enumeration + membership
/// - `Successors` — edge traversal
/// - `DirectedGraph` — convenience alias: `VertexSet + Successors`
///
/// ## Contract
///
/// `iter` must yield each vertex exactly once.
///
/// ## Design decisions
///
/// **Fixed vertex type (Int):**
/// MoonBit traits cannot have type parameters or associated types, so we
/// fix vertices to `Int`. If your vertices are strings or custom IDs,
/// map them to `Int` indices.
///
/// **Iter-based iteration:**
/// `iter` and `successors` return `Iter[Int]` — MoonBit's external iterator
/// (`struct Iter[X](fn() -> X?)`). Pull-based: call `.next()` for one vertex
/// at a time. Enables pause/resume (Tarjan SCC), early termination
/// (`has_vertex` short-circuits via `Iter::contains`), and lazy composition.
///
/// **Callback methods defaulted:**
/// `each_vertex` and `each_successor` delegate to `Iter::each` for push-style
/// algorithms (DFS, BFS, toposort).
///
/// **Reverse-direction queries:**
/// Types that also implement `Predecessors` can be wrapped with `Reversed[G]`
/// for zero-cost reverse traversal. `AdjacencyMap` and `DenseGraph` both
/// implement `Predecessors` via bidirectional adjacency storage.
///
/// ## Example: minimal implementation
///
/// For types that can enumerate vertices AND follow edges:
/// ```
/// struct MyGraph { edges : Array[Array[Int]] }
///
/// impl VertexSet for MyGraph with iter(self) {
///   (0).until(self.edges.length())
/// }
/// impl Successors for MyGraph with successors(self, v) {
///   self.edges[v].iter()
/// }
/// impl DirectedGraph for MyGraph
/// // vertex_count, has_vertex, each_vertex, each_successor,
/// // dfs_fold, bfs_fold all work via defaults.
/// ```
///
/// For types that can only follow edges (no vertex enumeration):
/// ```
/// impl Successors for ImplicitGraph with successors(self, v) {
///   f(v)  // compute successors from a function
/// }
/// // reachable, dfs_fold, bfs_fold, outdegree all work.
/// ```

// ============================================================
// VertexSet — enumeration and membership
// ============================================================

///|
/// Types that can enumerate their vertices.
///
/// Required method: `iter() -> Iter[Int]`.
/// All others have O(V) defaults derived from `iter`.
pub(open) trait VertexSet {
  fn iter(Self) -> Iter[Int]
  fn each_vertex(Self, (Int) -> Unit) -> Unit = _
  fn vertex_count(Self) -> Int = _
  fn has_vertex(Self, Int) -> Bool = _
}

///|
/// Default each_vertex: delegates to `Iter::each`.
impl VertexSet with fn each_vertex(self, f) {
  VertexSet::iter(self).each(f)
}

///|
/// Default vertex_count: O(V) — counts via `Iter::count`.
/// Override for O(1) if your type tracks vertex count directly.
impl VertexSet with fn vertex_count(self) {
  VertexSet::iter(self).count()
}

///|
/// Default has_vertex: uses `Iter::contains` which short-circuits on match.
/// O(1) best case, O(V) worst case. Override for O(1) if your type
/// supports constant-time membership.
impl VertexSet with fn has_vertex(self, v) {
  VertexSet::iter(self).contains(v)
}

// ============================================================
// Successors — edge traversal
// ============================================================

///|
/// Types that can follow edges from a vertex.
///
/// Required method: `successors(v) -> Iter[Int]`.
/// `dfs_fold` and `bfs_fold` have defaults using `each_successor`
/// with a `Map[Int, Bool]` visited set; override for faster
/// visited-set tracking (e.g. `FixedArray[Bool]` for dense IDs).
pub(open) trait Successors {
  fn successors(Self, Int) -> Iter[Int]
  fn[Acc] dfs_fold(Self, Int, Acc, (Acc, Int) -> (Acc, Bool)) -> Acc = _
  fn[Acc] bfs_fold(Self, Int, Acc, (Acc, Int) -> (Acc, Bool)) -> Acc = _
  fn each_successor(Self, Int, (Int) -> Unit) -> Unit = _
}

///|
/// Default each_successor: delegates to `Iter::each`.
impl Successors with fn each_successor(self, v, f) {
  Successors::successors(self, v).each(f)
}

///|
/// Default dfs_fold: DFS with `Map[Int, Bool]` visited set.
/// Stack-safe iterative implementation. Override for types that can
/// provide faster visited-set tracking (e.g. `FixedArray[Bool]` for dense IDs).
///
/// Note: `Successors`-only traversal starts from a known vertex.
/// The default does not validate that `start` exists in any vertex set —
/// callers that need membership checks should require `VertexSet`
/// in addition to `Successors`.
impl Successors with fn dfs_fold(self, start, init, f) {
  let visited : Map[Int, Bool] = Map([])
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited.contains(v) {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    let mark = stack.length()
    Successors::each_successor(self, v, fn(w) {
      if !visited.contains(w) {
        stack.push(w)
      }
    })
    let mut lo = mark
    let mut hi = stack.length() - 1
    while lo < hi {
      let tmp = stack[lo]
      stack[lo] = stack[hi]
      stack[hi] = tmp
      lo = lo + 1
      hi = hi - 1
    }
  }
  acc
}

///|
/// Default bfs_fold: BFS with `Map[Int, Bool]` visited set.
/// Array-based FIFO queue with head pointer. Override for types that
/// can provide O(1) visited-set tracking (e.g. `FixedArray[Bool]` for dense IDs).
///
/// Same "known start" caveat as `dfs_fold` — does not validate membership.
impl Successors with fn bfs_fold(self, start, init, f) {
  let visited : Map[Int, Bool] = Map([])
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
    Successors::each_successor(self, v, fn(w) {
      if !visited.contains(w) {
        visited[w] = true
        queue.push(w)
      }
    })
  }
  acc
}

// ============================================================
// DirectedGraph — convenience alias
// ============================================================

///|
/// Convenience trait: `VertexSet + Successors`.
///
/// Use this bound when an algorithm needs both vertex enumeration
/// AND edge traversal. Most algorithms (toposort, SCC, dfs_events)
/// require `DirectedGraph`. Local reachability and BFS/DFS from a
/// known start only need `Successors`.
///
/// Implementors: implement `VertexSet` and `Successors` separately,
/// then add `impl DirectedGraph for YourType` (no methods needed).
pub(open) trait DirectedGraph: VertexSet + Successors {}

// ============================================================
// Predecessors — reverse-direction observation capability
// ============================================================

///|
/// Types that can efficiently answer "which vertices point to v?"
/// implement this trait alongside `DirectedGraph`. No default
/// implementation is provided — an O(V+E) scan default would be
/// a performance trap.
///
/// Used by `Reversed[G]` to swap `successors` and `predecessors`.
pub(open) trait Predecessors {
  fn predecessors(Self, Int) -> Iter[Int]
}
