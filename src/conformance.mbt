///|
/// # DirectedGraph conformance checks
///
/// Property-test helper for verifying that a `DirectedGraph` implementation
/// honors the trait contract. Adopters call `check_conformance(g)` on
/// graphs produced by their type (typically inside a test) and assert that
/// the returned violation list is empty.
///
/// ## Why this exists
///
/// The `DirectedGraph` trait has an implicit contract — `iter()` yields
/// every vertex exactly once, `successors(v)` only yields vertices that
/// are also in `iter()`, `has_vertex` agrees with `iter`, and so on.
/// Algorithms like `toposort`, `tarjan_scc`, and `find_cycle` silently
/// misbehave on impls that violate this contract (missed subgraphs,
/// wrong vertex counts, spurious cycles). A runtime contract check can't
/// prevent this, but a test-time check can — run `check_conformance` in
/// your impl's test suite on representative instances.
///
/// ## Laws checked
///
/// - **A.** `iter()` yields each vertex exactly once (no duplicates)
/// - **B.** Closure: every `w ∈ successors(v)` is also in `iter()` for v ∈ `iter()`
/// - **C.** `has_vertex(v) == true` for every v in `iter()`, and
///   `has_vertex(v) == false` for a small spot-check of sentinel values
///   known to be absent (MAX_VALUE, MIN_VALUE, and nearest out-of-range
///   neighbours). **Limitation:** this is a spot check, not a proof —
///   a pathological `has_vertex` that only lies on un-sampled vertices
///   can still slip past. Treat the absent-vertex side as a sanity ward,
///   not a guarantee.
/// - **D.** `vertex_count() == iter().count()`
/// - **E.** `successors(v)` contains no duplicates for each v
/// - **F.** `each_vertex` / `each_successor` defaults agree with the `iter` / `successors` sources
///
/// Law G (Predecessors symmetry) is in `check_predecessors_conformance`,
/// which also requires the `Predecessors` capability.
///
/// ## Return shape
///
/// Returns `Array[String]` — one human-readable line per violation.
/// Empty array means the graph is conformant. Test callers typically do:
///
/// ```moonbit
/// let violations = @alga.check_conformance(my_graph)
/// assert_eq(violations, [])
/// ```
///
/// The check is O(V + E) time and O(V + E) space. Not appropriate for
/// production hot paths — this is a development-time correctness tool.

///|
/// Check that a graph conforms to the `DirectedGraph` trait contract.
///
/// Returns a list of human-readable violation messages; an empty list
/// means the graph is conformant. See the module doc for the laws checked.
pub fn[G : DirectedGraph] check_conformance(graph : G) -> Array[String] {
  let violations : Array[String] = []
  // Capture iter() output raw (with any duplicates preserved) and also
  // build a deduplicated set for downstream closure checks.
  // - iter_raw: what Laws D and F compare against, since the default
  //   vertex_count/each_vertex delegate to iter() including duplicates.
  // - iter_set: vertex membership oracle for Law B.
  let iter_raw : Array[Int] = []
  let iter_set : @hashset.HashSet[Int] = @hashset.new()
  let dup_reported : @hashset.HashSet[Int] = @hashset.new()
  for v in G::iter(graph) {
    iter_raw.push(v)
    if iter_set.contains(v) {
      // Duplicate — report once per offending vertex, then keep going so
      // downstream checks still run (membership remains correct).
      if !dup_reported.contains(v) {
        dup_reported.add(v)
        violations.push("Law A: iter() yielded duplicate vertex \{v}")
      }
    } else {
      iter_set.add(v)
    }
  }
  // Law D: vertex_count agrees with the raw iter count. Defaults to
  // iter().count() so duplicate-iter impls still satisfy this against
  // the default; only a custom override can fail D in isolation.
  let vc = G::vertex_count(graph)
  if vc != iter_raw.length() {
    violations.push(
      "Law D: vertex_count() = \{vc} but iter().count() = \{iter_raw.length()}",
    )
  }
  // Law C: has_vertex agrees with iter for present vertices, and returns
  // false for vertices observably outside iter (spot-checked — we can't
  // enumerate the complement).
  for v in iter_set {
    if !G::has_vertex(graph, v) {
      violations.push(
        "Law C: iter() yielded \{v} but has_vertex(\{v}) returned false",
      )
    }
  }
  // Negative consistency: pick a few candidate vertices that could not
  // have come from iter (max+1, min-1, and a large-magnitude sentinel)
  // and require has_vertex returns false.
  let outside = outside_candidates(iter_raw)
  for v in outside {
    if G::has_vertex(graph, v) {
      violations.push(
        "Law C: has_vertex(\{v}) returned true but \{v} is not in iter()",
      )
    }
  }
  // Laws B + E: successors closure + no duplicates.
  for v in iter_set {
    let succ_seen : @hashset.HashSet[Int] = @hashset.new()
    for w in G::successors(graph, v) {
      if succ_seen.contains(w) {
        violations.push("Law E: successors(\{v}) yielded duplicate vertex \{w}")
      } else {
        succ_seen.add(w)
      }
      if !iter_set.contains(w) {
        violations.push(
          "Law B: successors(\{v}) yielded \{w}, which is not in iter()",
        )
      }
    }
  }
  // Law F: each_vertex agrees with iter() as a multiset (duplicates and all).
  let ev_list : Array[Int] = []
  G::each_vertex(graph, fn(v) { ev_list.push(v) })
  if !multiset_eq(ev_list, iter_raw) {
    violations.push(
      "Law F: each_vertex visited \{ev_list.length()} vertices, iter() yielded \{iter_raw.length()}; multisets differ",
    )
  }
  // Law F cont'd: each_successor agrees with successors() for each vertex.
  for v in iter_set {
    let es_list : Array[Int] = []
    G::each_successor(graph, v, fn(w) { es_list.push(w) })
    let su_list : Array[Int] = G::successors(graph, v).collect()
    if !multiset_eq(es_list, su_list) {
      violations.push(
        "Law F: each_successor(\{v}) visited \{es_list.length()} vertices, successors(\{v}) yielded \{su_list.length()}; multisets differ",
      )
    }
  }
  violations
}

///|
/// Pick a small set of vertex IDs guaranteed not to be in `iter_raw`.
/// Used for Law C negative consistency — we can't enumerate the complement
/// of iter(), but we can spot-check sentinels that are guaranteed outside
/// any finite vertex set we just observed.
fn outside_candidates(iter_raw : Array[Int]) -> Array[Int] {
  if iter_raw.length() == 0 {
    // Any value works as "not in iter" when iter is empty.
    return [0, 1, -1, @int.MAX_VALUE, @int.MIN_VALUE]
  }
  let mut lo = iter_raw[0]
  let mut hi = iter_raw[0]
  for v in iter_raw {
    if v < lo {
      lo = v
    }
    if v > hi {
      hi = v
    }
  }
  let candidates : Array[Int] = []
  if hi < @int.MAX_VALUE {
    candidates.push(hi + 1)
  }
  if lo > @int.MIN_VALUE {
    candidates.push(lo - 1)
  }
  candidates.push(@int.MAX_VALUE)
  candidates.push(@int.MIN_VALUE)
  // Filter out any candidate that somehow appeared (edge case if iter
  // contains both max and min): we want guaranteed-outside only.
  let iter_set : @hashset.HashSet[Int] = @hashset.new()
  for v in iter_raw {
    iter_set.add(v)
  }
  let result : Array[Int] = []
  for c in candidates {
    if !iter_set.contains(c) {
      result.push(c)
    }
  }
  result
}

///|
/// Check `Predecessors` conformance in addition to `DirectedGraph` laws.
///
/// Runs `check_conformance` first, then adds:
///
/// - **G.** Symmetry: `u ∈ predecessors(v) iff v ∈ successors(u)` for all
///   vertices u, v in `iter()`.
/// - **E'.** `predecessors(v)` contains no duplicates for each v.
pub fn[G : DirectedGraph + Predecessors] check_predecessors_conformance(
  graph : G,
) -> Array[String] {
  let violations = check_conformance(graph)
  // Collect vertices once — no need to re-run iter duplicate check.
  let iter_list : Array[Int] = G::iter(graph).collect()
  // Build forward edge set: (u, v) for v ∈ successors(u).
  let forward : @hashset.HashSet[(Int, Int)] = @hashset.new()
  for u in iter_list {
    for v in G::successors(graph, u) {
      forward.add((u, v))
    }
  }
  // Build backward edge set: (u, v) for u ∈ predecessors(v).
  // Also checks Law E' (no duplicate predecessors per vertex).
  let backward : @hashset.HashSet[(Int, Int)] = @hashset.new()
  for v in iter_list {
    let pred_seen : @hashset.HashSet[Int] = @hashset.new()
    for u in Predecessors::predecessors(graph, v) {
      if pred_seen.contains(u) {
        violations.push(
          "Law E': predecessors(\{v}) yielded duplicate vertex \{u}",
        )
      } else {
        pred_seen.add(u)
      }
      backward.add((u, v))
    }
  }
  // Law G: forward and backward edge sets must match.
  for edge in forward {
    if !backward.contains(edge) {
      violations.push(
        "Law G: \{edge.1} ∈ successors(\{edge.0}) but \{edge.0} ∉ predecessors(\{edge.1})",
      )
    }
  }
  for edge in backward {
    if !forward.contains(edge) {
      violations.push(
        "Law G: \{edge.0} ∈ predecessors(\{edge.1}) but \{edge.1} ∉ successors(\{edge.0})",
      )
    }
  }
  violations
}

///|
/// Multiset equality over Int arrays. O(n) via hash counting.
fn multiset_eq(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let counts : @hashmap.HashMap[Int, Int] = @hashmap.new()
  for x in a {
    match counts.get(x) {
      Some(n) => counts[x] = n + 1
      None => counts[x] = 1
    }
  }
  for x in b {
    match counts.get(x) {
      Some(n) => if n == 1 { counts.remove(x) } else { counts[x] = n - 1 }
      None => return false
    }
  }
  counts.length() == 0
}
