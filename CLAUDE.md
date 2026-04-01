# alga

Algebraic graphs for MoonBit — directed graph trait and algorithm library inspired by Haskell's alga.

@~/.claude/moonbit-base.md

## Project Structure

Single module: `dowdiness/alga`

| Package | Path | Purpose |
|---------|------|---------|
| `dowdiness/alga` | `src/` | Core library: DirectedGraph trait, AdjacencyMap, GraphSym, algorithms (DFS, BFS, toposort, SCC) |
| `dowdiness/alga/experiment` | `src/experiment/` | Performance experiments and benchmarks |

## Commands

```bash
moon check && moon test        # lint + tests (includes property-based law tests)
moon bench --release           # benchmarks (always --release)
moon info && moon fmt          # before committing
```

## Key Facts

- **Architecture:** Two-layer design — Layer A (observation via `DirectedGraph` trait) + Layer B (construction via `GraphSym` trait + `Graph` enum), connected by `foldg` bridge
- **Fixed vertex type:** Vertices are `Int` (MoonBit traits lack type parameters/associated types)
- **Iter-based trait:** `DirectedGraph` requires `iter() -> Iter[Int]` and `successors(v) -> Iter[Int]` (pull-based). Callback methods `each_vertex`/`each_successor` are defaulted. `has_vertex` short-circuits via `Iter::contains`.
- **Predecessors trait:** Optional capability trait for reverse-direction queries. `AdjacencyMap` and `DenseGraph` both implement it via bidirectional adjacency storage. Enables `Reversed[G]` zero-cost adaptor.
- **Iterative algorithms:** DFS and SCC use explicit stacks, not recursion (tested up to 10K+ vertices)
- **SCC algorithms:** Kosaraju (`AdjacencyMap::scc`, O(1) transpose) and Tarjan (`tarjan_scc`, generic over `DirectedGraph`, no transpose)
- **All algorithms** are generic over `DirectedGraph` (except Kosaraju SCC and condensation)
- **Property tests:** All 8 algebraic graph laws (Mokhov 2017) verified with `moonbitlang/quickcheck`
- **External dep:** `moonbitlang/quickcheck` (aliased `@qc`) for property-based testing with shrinking

## References

- Andrey Mokhov, [Algebraic Graphs with Class](https://dl.acm.org/doi/10.1145/3122955.3122956) (Haskell Symposium, 2017)
- Haskell [algebraic-graphs](https://hackage.haskell.org/package/algebraic-graphs) package
