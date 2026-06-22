# Decisions Needed

Items requiring human judgment, surfaced by triage.

## Resolved

### DenseGraph promotion → PROMOTED (2026-06-22)

API is stable. `DenseGraph` has been in the production package since v0.2.0.
Experiment package archived; report at `docs/archive/2026-03-31-perf-experiment-report.md`.

### NodeFiltered graph adaptor → WON'T DO (2026-06-22)

Zero-copy `NodeFiltered[G]` for scope-restricted traversals. No adopter requesting
it. Current consumers can collect + filter + rebuild. Revisit if a consumer reports
allocation pressure from vertex filtering on large graphs.

### Traversal control flow → WON'T DO (2026-06-22)

`ControlFlow` enum for `dfs_fold`/`bfs_fold` callbacks. Current `(Acc, Bool)`
handles early termination. `dfs_events` provides pull-based alternative. Revisit
if a consumer needs subtree-skipping in fold callbacks.
