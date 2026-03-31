// Benchmarks: recursive vs inner_fn vs letrec vs iterative vs direct
// Run with: moon bench --release
//
// 5 variants:
//   recursive — original foldg, passes all 5 params per recursive call
//   inner_fn  — fn go(g) captures params in closure (not tail-recursive)
//   letrec    — letrec go = fn(g) (not tail-recursive, same as inner_fn)
//   cps       — letrec go = fn(g, k) CPS, all calls in tail position (TCO)
//   iter      — explicit work/result stacks, no recursion
//   direct    — collects edges first, builds AdjacencyMap once (O(V+E))

// === to_adjacency_map: path_100 ===

///|
test "bench/foldg/recursive/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_recursive(g)) })
}

///|
test "bench/foldg/inner_fn/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_inner_fn(g)) })
}

///|
test "bench/foldg/letrec/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_letrec(g)) })
}

///|
test "bench/foldg/iter/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_iter(g)) })
}

///|
test "bench/foldg/cps/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_cps(g)) })
}

///|
test "bench/foldg/direct/path_100" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(100, fn(i) { i }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}

// === to_adjacency_map: path_1000 ===

///|
test "bench/foldg/recursive/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_recursive(g)) })
}

///|
test "bench/foldg/inner_fn/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_inner_fn(g)) })
}

///|
test "bench/foldg/letrec/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_letrec(g)) })
}

///|
test "bench/foldg/iter/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_iter(g)) })
}

///|
test "bench/foldg/cps/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_cps(g)) })
}

///|
test "bench/foldg/direct/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}

// === foldg for vertex count (lightweight B = Int, isolates fold overhead) ===

///|
test "bench/foldg_count/recursive/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() {
    b.keep(
      @alga.foldg(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) { a + b }),
    )
  })
}

///|
test "bench/foldg_count/inner_fn/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() {
    b.keep(
      foldg_inner_fn(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) { a + b }),
    )
  })
}

///|
test "bench/foldg_count/letrec/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() {
    b.keep(
      foldg_letrec(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) { a + b }),
    )
  })
}

///|
test "bench/foldg_count/cps/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() {
    b.keep(
      foldg_cps(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) { a + b }),
    )
  })
}

///|
test "bench/foldg_count/iter/path_1000" (b : @bench.T) {
  let g = @alga.Graph::path(Array::makei(1000, fn(i) { i }))
  b.bench(fn() {
    b.keep(
      @alga.foldg_iter(g, 0, fn(_v) { 1 }, fn(a, b) { a + b }, fn(a, b) {
        a + b
      }),
    )
  })
}

// === to_adjacency_map: clique_50 (balanced, many edges) ===

///|
test "bench/foldg/recursive/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_recursive(g)) })
}

///|
test "bench/foldg/inner_fn/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_inner_fn(g)) })
}

///|
test "bench/foldg/letrec/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_letrec(g)) })
}

///|
test "bench/foldg/iter/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_iter(g)) })
}

///|
test "bench/foldg/cps/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(to_adjacency_map_cps(g)) })
}

///|
test "bench/foldg/direct/clique_50" (b : @bench.T) {
  let g = @alga.Graph::clique(Array::makei(50, fn(i) { i }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}

// === to_adjacency_map: star_1000 (shallow, wide) ===

///|
test "bench/foldg/recursive/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(to_adjacency_map_recursive(g)) })
}

///|
test "bench/foldg/inner_fn/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(to_adjacency_map_inner_fn(g)) })
}

///|
test "bench/foldg/letrec/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(to_adjacency_map_letrec(g)) })
}

///|
test "bench/foldg/iter/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(to_adjacency_map_iter(g)) })
}

///|
test "bench/foldg/cps/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(to_adjacency_map_cps(g)) })
}

///|
test "bench/foldg/direct/star_1000" (b : @bench.T) {
  let g = @alga.Graph::star(0, Array::makei(999, fn(i) { i + 1 }))
  b.bench(fn() { b.keep(g.to_adjacency_map()) })
}
