# Decisions Needed

Items requiring human judgment, surfaced by triage.

## Active decisions

### DenseGraph promotion — stabilize or keep experimental?

**Source:** `docs/TODO.md` → "DenseGraph promotion"
**Context:** `DenseGraph` is public, has full `DirectedGraph` + `Predecessors`
impls, and benchmarks at 8–23× over `AdjacencyMap`. But
`src/experiment/EXPERIMENT_REPORT.md` still treats it as experimental,
and the "close out remaining experiment-only code" step is unresolved.
Deciding to promote would cascade into GenCounter adoption and a
specialized `DenseGraph::dfs_events`.
**Blocks:** GenCounter for visited sets, specialized DenseGraph::dfs_events
**Evidence:** Code is public and tested; interface is exported; experiment
report wording is stale. No `docs/plans/*.md` plan exists.
**Added:** 2026-06-22

### NodeFiltered graph adaptor — implement or archive?

**Source:** `docs/TODO.md` → "NodeFiltered graph adaptor"
**Context:** A zero-copy `NodeFiltered[G]` adaptor implementing
`DirectedGraph` for scope-restricted traversals. Has a source analysis
in `docs/specs/2026-04-01-petgraph-analysis.md` but no implementation,
no plan, and no adopter requesting it.
**Blocks:** Nothing directly
**Evidence:** Spec analysis exists; no code; no plan file; no open issue.
**Added:** 2026-06-22

### Traversal control flow — implement or archive?

**Source:** `docs/TODO.md` → "Traversal control flow"
**Context:** `dfs_fold`/`bfs_fold` callbacks return `(Acc, Bool)` for
early termination. A `ControlFlow` enum would be cleaner. Already
partially mitigated by `dfs_events` (Iter-based pull traversal). No
implementation, no plan, no adopter requesting it.
**Blocks:** Nothing directly
**Evidence:** Spec analysis in petgraph doc; no code; no plan file.
**Added:** 2026-06-22
