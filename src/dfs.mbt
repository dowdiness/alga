///|
/// # Depth-First Search (DFS)
///
/// DFS explores a graph by going as deep as possible along each branch
/// before backtracking. It's the foundation of many graph algorithms
/// (cycle detection, topological sort, SCC, path finding).
///
/// ## Implementation: iterative with explicit stack
///
/// Classic DFS is recursive, but recursion depth equals the longest path
/// in the graph — which can blow the call stack on deep graphs (we hit
/// this at ~10K vertices in WASM). The iterative version uses an explicit
/// `Array` as a stack, making it safe for arbitrarily deep graphs.
///
/// Successors are pushed directly from the `each_successor` callback
/// then reversed in place (mark-and-reverse), so the first successor is
/// processed first (matching recursive DFS order) without per-vertex
/// temporary array allocation.
///
/// ## The fold pattern
///
/// `dfs_fold` is a generalization: instead of collecting vertices into a
/// list, it folds an accumulator over visited vertices. The callback
/// returns `(new_acc, should_continue)` — returning `false` for
/// `should_continue` stops traversal early (useful for "find first" queries).
///
/// `reachable` is the common case — collects all reachable vertices.

///|
/// DFS fold over vertices reachable from `start`.
///
/// Visits each vertex exactly once. `f` receives the current accumulator
/// and the visited vertex, and returns `(new_acc, should_continue)`.
/// When `should_continue` is `false`, traversal halts immediately.
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
pub fn[G : DirectedGraph, Acc] dfs_fold(
  graph : G,
  start : Int,
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let stack : Array[Int] = [start]
  let mut acc = init
  while stack.length() > 0 {
    let v = stack.unsafe_pop()
    if visited.get(v) == Some(true) {
      continue
    }
    visited[v] = true
    let result = f(acc, v)
    acc = result.0
    if !result.1 {
      break
    }
    // Push successors directly, then reverse in place so first successor
    // is on top of the stack. Avoids per-vertex temporary array allocation.
    let mark = stack.length()
    G::each_successor(graph, v, fn(w) {
      if visited.get(w) != Some(true) {
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
/// All vertices reachable from `start`, in DFS pre-order.
pub fn[G : DirectedGraph] reachable(graph : G, start : Int) -> Array[Int] {
  dfs_fold(graph, start, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

///|
/// Multi-source DFS fold over vertices reachable from any vertex in `starts`.
///
/// Seeds the DFS stack with all start vertices instead of one, enabling
/// frontier-based traversal. Same motivation as `bfs_fold_multi` — see
/// its doc comment for the multi-source vs looping-single-source rationale.
///
/// ## Ordering
///
/// Start vertices are pushed in reverse order so `starts[0]` is on top
/// of the stack and processed first. When source sub-trees are disjoint,
/// `starts[0]` is fully explored before `starts[1]`. When sub-trees
/// overlap, vertices reachable from multiple starts are visited on first
/// encounter (from whichever source reaches them first in DFS order).
///
/// ## Seeding
///
/// - Invalid starts (not in the graph) are silently skipped via `has_vertex`
/// - Duplicate starts are deduplicated before traversal begins
///
/// Time: O(V + E) where V and E are the reachable vertices and edges.
/// Seed validation calls `has_vertex` — override it for O(1) on custom types.
pub fn[G : DirectedGraph, Acc] dfs_fold_multi(
  graph : G,
  starts : Array[Int],
  init : Acc,
  f : (Acc, Int) -> (Acc, Bool),
) -> Acc {
  let visited : Map[Int, Bool] = Map::new()
  let stack : Array[Int] = []
  // Seed in reverse order so starts[0] ends up on top of the stack (LIFO).
  // Use visited for dedup — seeds are pushed but NOT marked as visited,
  // so the main loop's visited-check + fold runs normally for each seed.
  // After seeding, clear visited so the main loop starts fresh.
  let seen : @hashset.HashSet[Int] = @hashset.new()
  let mut i = starts.length() - 1
  while i >= 0 {
    let s = starts[i]
    if !seen.contains(s) && G::has_vertex(graph, s) {
      seen.add(s)
      stack.push(s)
    }
    i = i - 1
  }
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
    // Push successors directly, then reverse in place so first successor
    // is on top of the stack. Avoids per-vertex temporary array allocation.
    let mark = stack.length()
    G::each_successor(graph, v, fn(w) {
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
/// All vertices reachable from any vertex in `starts`, in DFS pre-order.
///
/// Convenience wrapper around `dfs_fold_multi` — collects all reachable
/// vertices into an array. Same relationship as `reachable` to `dfs_fold`.
pub fn[G : DirectedGraph] reachable_multi(
  graph : G,
  starts : Array[Int],
) -> Array[Int] {
  dfs_fold_multi(graph, starts, [], fn(arr, v) {
    arr.push(v)
    (arr, true)
  })
}

///|
/// # DFS Edge Classification
///
/// Events emitted during a depth-first traversal. Every edge in the graph
/// is classified into exactly one of three types (tree, back, cross/forward),
/// and every vertex emits Discover (pre-order) and Finish (post-order).
///
/// ## Vertex coloring
///
/// - **White** (undiscovered): not yet seen by the DFS
/// - **Gray** (in progress): discovered but not finished — on the DFS stack
/// - **Black** (finished): all descendants fully explored
///
/// Edge classification follows from the target vertex's color when the edge
/// is examined: white → TreeEdge, gray → BackEdge, black → CrossForwardEdge.
pub(all) enum DfsEvent {
  /// Vertex entered — pre-order. Vertex transitions white → gray.
  Discover(Int)
  /// All descendants done — post-order. Vertex transitions gray → black.
  Finish(Int)
  /// (u, v): v was white. v will be discovered on the next `.next()` call.
  TreeEdge(Int, Int)
  /// (u, v): v is gray (ancestor on stack). Indicates a cycle: v →...→ u → v.
  BackEdge(Int, Int)
  /// (u, v): v is black (already finished). Merged forward + cross edges.
  CrossForwardEdge(Int, Int)
}

///|
/// DFS event iterator — classifies every edge and emits vertex enter/exit events.
///
/// Returns a lazy `Iter[DfsEvent]`. Each `.next()` call advances the DFS by
/// one step and returns the next event. Handles disconnected components by
/// iterating all vertices from `graph.iter()`.
///
/// ## State machine
///
/// The closure captures:
/// - `enter_pending`: vertex awaiting Discover (checked first each call)
/// - `frames`: stack of `(vertex, Iter[Int])` for successor processing
/// - `state`: `Map[Int, Int]` — absent = white, >= 0 = gray (discovery index), -1 = black
/// - `roots`: `Iter[Int]` from `graph.iter()` for finding unvisited roots
///
/// ## Event ordering
///
/// `TreeEdge(u, v)` and `Discover(v)` are separate events on separate `.next()`
/// calls. `enter_pending` is checked before the stack, so `Discover(v)` fires
/// before u's remaining successors — correct DFS order.
///
/// Time: O(V + E). Space: O(V).
pub fn[G : DirectedGraph] dfs_events(graph : G) -> Iter[DfsEvent] {
  // Vertex state: absent = white, >= 0 = gray (discovery index), -1 = black
  let state : Map[Int, Int] = Map::new()
  let frames : Array[(Int, Iter[Int])] = []
  let roots = G::iter(graph)
  let mut counter = 0
  // Vertex awaiting Discover — checked first on each .next() call.
  // When set, the next event is Discover(v) and a processing frame is pushed.
  let mut enter_pending : Int? = None
  Iter::new(fn() {
    // Loop until we produce an event or exhaust the graph
    while true {
      // Priority 1: pending vertex needs Discover
      match enter_pending {
        Some(v) => {
          enter_pending = None
          state[v] = counter
          counter = counter + 1
          frames.push((v, G::successors(graph, v)))
          break Some(Discover(v))
        }
        None => ()
      }
      // Priority 2: process top stack frame
      if frames.length() > 0 {
        let top_idx = frames.length() - 1
        let v = frames[top_idx].0
        let iter = frames[top_idx].1
        match iter.next() {
          Some(w) =>
            match state.get(w) {
              None => {
                // White: tree edge, schedule Discover(w) for next call
                enter_pending = Some(w)
                break Some(TreeEdge(v, w))
              }
              Some(s) =>
                if s >= 0 {
                  // Gray: back edge (w is ancestor on stack)
                  break Some(BackEdge(v, w))
                } else {
                  // Black (s == -1): cross/forward edge
                  break Some(CrossForwardEdge(v, w))
                }
            }
          None => {
            // All successors exhausted — finish v
            state[v] = -1
            let _ = frames.unsafe_pop()
            break Some(Finish(v))
          }
        }
      }
      // Priority 3: find next unvisited root
      let mut found_root = false
      while roots.next() is Some(r) {
        if !state.contains(r) {
          enter_pending = Some(r)
          found_root = true
          break
        }
      }
      if !found_root {
        break None
      }
      // Loop back to process enter_pending
    } nobreak {
      None
    }
  })
}
