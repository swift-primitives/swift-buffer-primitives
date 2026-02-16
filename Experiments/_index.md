# Buffer Primitives Experiments

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| [ring-buffer-architecture-validation](ring-buffer-architecture-validation/) | Validate three-layer architecture (Header / Static Ops / Composed Type) with Storage.Heap | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [initialization-consistency](initialization-consistency/) | Verify Storage.Initialization consistency across Linear, Ring, and Slab disciplines | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [composed-vs-static-benchmark](composed-vs-static-benchmark/) | Benchmark composed type (Ring.Growable) vs direct static method calls | 2026-02-03 | Apple Swift 6.2.3 | CONFIRMED |
| [slab-deinit-workaround](slab-deinit-workaround/) | MoveOnlyChecker crash in Buffer.Slab.deinit — workaround: extract Ones.View into local | 2026-02-06 | Apple Swift 6.2.3 | CONFIRMED |
| [noncopyable-enum-modify](noncopyable-enum-modify/) | Validate that _modify cannot yield into enum payloads for ~Copyable types (Optional can via &optional!) | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [static-property-view-pattern](static-property-view-pattern/) | Validate static + Property.View pattern: consuming ~Copyable, CoW overloads, _modify, callAsFunction, overload coexistence | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [spill-building-block](spill-building-block/) | Test generic Spill\<Inline, Heap\> building block for factoring Small buffer pattern — mechanically feasible but net savings marginal | 2026-02-12 | Apple Swift 6.2.3 | CONFIRMED |
| [rawlayout-release-verifier-crash](rawlayout-release-verifier-crash/) | LLVM verifier "Instruction does not dominate all uses!" — 30 variants of @_rawLayout + class reference combinations; none reproduce the crash in isolation | 2026-02-15 | Xcode 26.0 beta 2 | REFUTED |
| [copy-propagation-noncopyable-enum](copy-propagation-noncopyable-enum/) | CopyPropagation SIL crash — consuming ~Copyable in enum switch + conditional loop with bitmap; 5 variants (concrete, generic, nested, value-generic, slab); none reproduce in isolation | 2026-02-15 | Xcode 26.0 beta 2 | REFUTED |
| [small-enum-modify-recovery](small-enum-modify-recovery/) | DiagnoseStaticExclusivity crash FIXED; recover _modify for heap case via let-binding pointer bypass; inline case not recoverable via pointer (borrow temporary) | 2026-02-16 | Apple Swift 6.2.3 | CONFIRMED |
