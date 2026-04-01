# DFS Edge Classification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `dfs_events(graph) -> Iter[DfsEvent]` — a pull-based DFS event iterator that classifies every edge as tree/back/cross-forward, generic over `DirectedGraph`.

**Architecture:** A `DfsEvent` enum with 5 variants and a `dfs_events` function that returns `Iter[DfsEvent]`. The iterator's closure captures a state machine: `enter_pending` (vertex awaiting Discover), a stack of `(vertex, Iter[Int])` frames, a `Map[Int, Int]` for vertex state (white/gray/black), and a root iterator for disconnected components. Each `.next()` call advances exactly one step.

**Tech Stack:** MoonBit, `Iter[DfsEvent]`, `moonbitlang/quickcheck` for property tests.

**Spec:** `docs/specs/2026-04-01-dfs-edge-classification-design.md`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `src/dfs.mbt` | Append | `DfsEvent` enum + `dfs_events` function |
| `src/dfs_test.mbt` | Append | Unit tests for `dfs_events` |
| `src/graph_expr_qc.mbt` | Append | Property tests |

No existing files are modified — this is purely additive.

---

### Task 1: Add DfsEvent enum and stub

**Files:**
- Modify: `src/dfs.mbt` (append after line 177)

- [ ] **Step 1: Add the DfsEvent enum**

Append to `src/dfs.mbt`:

```moonbit
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
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Pass (enum is defined but not yet used).

- [ ] **Step 3: Commit**

```bash
git add src/dfs.mbt
git commit -m "feat: add DfsEvent enum for edge classification"
```

---

### Task 2: Write failing tests for dfs_events

**Files:**
- Modify: `src/dfs_test.mbt` (append after line 215)

- [ ] **Step 1: Add unit tests**

Append to `src/dfs_test.mbt`:

```moonbit
// --- dfs_events ---

///|
test "dfs_events empty graph" {
  let g = @alga.AdjacencyMap::empty()
  let events = @alga.dfs_events(g).collect()
  assert_eq(events.length(), 0)
}

///|
test "dfs_events single vertex" {
  let g = @alga.AdjacencyMap::vertex(1)
  let events = @alga.dfs_events(g).collect()
  assert_eq(events.length(), 2)
  assert_true(events[0] is @alga.Discover(1))
  assert_true(events[1] is @alga.Finish(1))
}

///|
test "dfs_events chain" {
  // 1 → 2 → 3
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3)])
  let events = @alga.dfs_events(g).collect()
  // Expected: Discover(1), TreeEdge(1,2), Discover(2), TreeEdge(2,3),
  //           Discover(3), Finish(3), Finish(2), Finish(1)
  assert_eq(events.length(), 8)
  // Count event types
  let mut discovers = 0
  let mut finishes = 0
  let mut tree_edges = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      @alga.TreeEdge(_, _) => tree_edges = tree_edges + 1
      _ => ()
    }
  }
  assert_eq(discovers, 3)
  assert_eq(finishes, 3)
  assert_eq(tree_edges, 2)
}

///|
test "dfs_events back edge (cycle)" {
  // 1 → 2 → 3 → 1
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1)])
  let events = @alga.dfs_events(g).collect()
  // Should contain exactly one BackEdge(3, 1)
  let back_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.BackEdge(u, v) => back_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(back_edges.length(), 1)
  assert_eq(back_edges[0], (3, 1))
}

///|
test "dfs_events cross/forward edge" {
  // 0 → 1 → 2, 0 → 2
  // Edge 0→2 is a cross/forward edge (2 is black when 0 examines it)
  let g = @alga.AdjacencyMap::from_edges([(0, 1), (1, 2), (0, 2)])
  let events = @alga.dfs_events(g).collect()
  let cf_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.CrossForwardEdge(u, v) => cf_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(cf_edges.length(), 1)
  assert_eq(cf_edges[0], (0, 2))
}

///|
test "dfs_events self loop" {
  let g = @alga.AdjacencyMap::from_edges([(1, 1)])
  let events = @alga.dfs_events(g).collect()
  // Self-loop: 1 is gray when edge 1→1 is examined → BackEdge
  let back_edges : Array[(Int, Int)] = []
  for e in events.iter() {
    match e {
      @alga.BackEdge(u, v) => back_edges.push((u, v))
      _ => ()
    }
  }
  assert_eq(back_edges.length(), 1)
  assert_eq(back_edges[0], (1, 1))
}

///|
test "dfs_events disconnected components" {
  // Two disconnected edges: 1→2, 3→4
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (3, 4)])
  let events = @alga.dfs_events(g).collect()
  let mut discovers = 0
  let mut finishes = 0
  for e in events.iter() {
    match e {
      @alga.Discover(_) => discovers = discovers + 1
      @alga.Finish(_) => finishes = finishes + 1
      _ => ()
    }
  }
  // All 4 vertices discovered and finished
  assert_eq(discovers, 4)
  assert_eq(finishes, 4)
}

///|
test "dfs_events works on DenseGraph" {
  // 0→1→2→0 (cycle)
  let g = @alga.DenseGraph::from_edges(3, [(0, 1), (1, 2), (2, 0)])
  let events = @alga.dfs_events(g).collect()
  let mut back_count = 0
  for e in events.iter() {
    if e is @alga.BackEdge(_, _) {
      back_count = back_count + 1
    }
  }
  assert_eq(back_count, 1)
}

///|
test "dfs_events early termination via break" {
  // Large chain, but we break after first BackEdge
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (2, 3), (3, 1), (3, 4), (4, 5)])
  let mut found_cycle = false
  for event in @alga.dfs_events(g) {
    if event is @alga.BackEdge(_, _) {
      found_cycle = true
      break
    }
  }
  assert_true(found_cycle)
}

///|
test "dfs_events total edge count" {
  // Diamond: 1→2, 1→3, 2→4, 3→4 (4 edges)
  let g = @alga.AdjacencyMap::from_edges([(1, 2), (1, 3), (2, 4), (3, 4)])
  let events = @alga.dfs_events(g).collect()
  let mut edge_count = 0
  for e in events.iter() {
    match e {
      @alga.TreeEdge(_, _) | @alga.BackEdge(_, _) | @alga.CrossForwardEdge(_, _) =>
        edge_count = edge_count + 1
      _ => ()
    }
  }
  assert_eq(edge_count, 4)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `dfs_events` is not defined yet.

- [ ] **Step 3: Commit failing tests**

```bash
git add src/dfs_test.mbt
git commit -m "test: add failing tests for dfs_events edge classification"
```

---

### Task 3: Implement dfs_events

**Files:**
- Modify: `src/dfs.mbt` (append after the DfsEvent enum)

- [ ] **Step 1: Implement dfs_events**

Append to `src/dfs.mbt` (after the DfsEvent enum):

```moonbit
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
    }
  })
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Clean compile.

- [ ] **Step 3: Run tests**

Run: `moon test`
Expected: All tests pass, including the new dfs_events tests.

- [ ] **Step 4: Commit**

```bash
git add src/dfs.mbt
git commit -m "feat: add dfs_events — pull-based DFS with edge classification

Iter[DfsEvent] iterator using state machine with enter_pending + frame stack.
Classifies every edge as TreeEdge, BackEdge, or CrossForwardEdge.
Emits Discover (pre-order) and Finish (post-order) for every vertex.
Generic over DirectedGraph, handles disconnected components.
O(V+E) time, O(V) space."
```

---

### Task 4: Add property tests

**Files:**
- Modify: `src/graph_expr_qc.mbt` (append)

- [ ] **Step 1: Add property tests**

Append to `src/graph_expr_qc.mbt`:

```moonbit
///|
/// Property: dfs_events emits exactly one Discover and one Finish per vertex.
test "prop: dfs_events Discover/Finish count matches vertex_count" {
  @qc.quick_check_fn(fn(g : Graph) -> Bool {
    let am = g.to_adjacency_map()
    let events = dfs_events(am).collect()
    let mut discovers = 0
    let mut finishes = 0
    for e in events.iter() {
      match e {
        Discover(_) => discovers = discovers + 1
        Finish(_) => finishes = finishes + 1
        _ => ()
      }
    }
    let vc = am.vertex_count()
    discovers == vc && finishes == vc
  }, max_success?=100)
}

///|
/// Property: every edge is classified exactly once.
/// Total classified edges (tree + back + cross/forward) equals edge_count.
test "prop: dfs_events classifies all edges" {
  @qc.quick_check_fn(fn(g : Graph) -> Bool {
    let am = g.to_adjacency_map()
    let events = dfs_events(am).collect()
    let mut edge_events = 0
    for e in events.iter() {
      match e {
        TreeEdge(_, _) | BackEdge(_, _) | CrossForwardEdge(_, _) =>
          edge_events = edge_events + 1
        _ => ()
      }
    }
    edge_events == am.edge_count()
  }, max_success?=100)
}
```

- [ ] **Step 2: Run tests**

Run: `moon test`
Expected: All tests pass, including property tests (200 random cases total).

- [ ] **Step 3: Commit**

```bash
git add src/graph_expr_qc.mbt
git commit -m "test: property tests for dfs_events edge classification

Two properties verified over 100 random graphs each:
1. Discover/Finish count matches vertex_count
2. Edge events (tree + back + cross/forward) equals edge_count"
```

---

### Task 5: Update interfaces, format, docs, finalize

**Files:**
- Regenerate: `src/pkg.generated.mbti`
- Modify: `docs/TODO.md`

- [ ] **Step 1: Run `moon info && moon fmt`**

Run: `moon info && moon fmt`

- [ ] **Step 2: Verify API changes**

Run: `git diff src/pkg.generated.mbti`

Expected new entries:
- `pub(all) enum DfsEvent { Discover(Int); Finish(Int); TreeEdge(Int, Int); BackEdge(Int, Int); CrossForwardEdge(Int, Int) }`
- `pub fn dfs_events[G : DirectedGraph](G) -> Iter[DfsEvent]`

- [ ] **Step 3: Run full test suite**

Run: `moon test`
Expected: All tests pass.

- [ ] **Step 4: Update TODO**

In `docs/TODO.md`, move "DFS edge classification" from Investigate to Done:

Remove the line:
```
- **DFS edge classification** — `dfs_classify` reporting `TreeEdge`, `BackEdge`, `CrossForwardEdge`, `Finish`. Makes DFS a universal building block for cycle detection, bridges, etc. Source: [petgraph analysis](specs/2026-04-01-petgraph-analysis.md#2-dfs-edge-classification)
```

Add to Done section:
```
- **~~DFS edge classification~~** — `dfs_events(graph) -> Iter[DfsEvent]` with 5 events: Discover, Finish, TreeEdge, BackEdge, CrossForwardEdge. Pull-based iterator, generic over `DirectedGraph`. Source: [spec](specs/2026-04-01-dfs-edge-classification-design.md)
```

- [ ] **Step 5: Commit**

```bash
git add src/pkg.generated.mbti docs/TODO.md
git commit -m "chore: regenerate interfaces, update TODO for dfs_events"
```
