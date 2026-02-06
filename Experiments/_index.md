# Buffer Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| [ring-buffer-architecture-validation](ring-buffer-architecture-validation/) | Validate three-layer architecture (Header / Static Ops / Composed Type) with Storage.Heap | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [initialization-consistency](initialization-consistency/) | Verify Storage.Initialization consistency across Linear, Ring, and Slab disciplines | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [composed-vs-static-benchmark](composed-vs-static-benchmark/) | Benchmark composed type (Ring.Growable) vs direct static method calls | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [slab-deinit-workaround](slab-deinit-workaround/) | MoveOnlyChecker crash in Buffer.Slab.deinit — workaround: extract Ones.View into local | 2026-02-06 | Apple Swift 6.2.3 | CONFIRMED |
