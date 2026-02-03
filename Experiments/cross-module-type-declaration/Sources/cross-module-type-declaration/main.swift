// MARK: - Cross-Module Type Declaration Verification
// Purpose: Verify that ~Copyable struct declarations in Core module can have
//          convenience inits (delegating to Core memberwise init), methods,
//          and protocol conformances added via extensions in a Variant module.
//
// Hypothesis: Core provides @inlinable package memberwise init. Variant modules
//             delegate to it via self.init(...) and can read/write package var
//             stored properties in methods and computed properties.
//
// Toolchain: Apple Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 6 variants pass
//   V1: Convenience init (delegating) + methods from Variant: CONFIRMED
//   V2: Bounded convenience init from Variant: CONFIRMED
//   V3: Protocol conformance from Variant: CONFIRMED
//   V4: Copyable (Core) + Variant init: CONFIRMED
//   V5: Deinit in Core (read-only self), init/methods from Variant: CONFIRMED
//   V6: No deinit, explicit mutating cleanup from Variant: CONFIRMED
//
// Critical finding: Memberwise init MUST be in Core (same module as struct).
//   Extensions in other modules can only add convenience inits that delegate
//   to self.init(...). Direct stored property assignment from cross-module
//   extensions produces: "'self' used before 'self.init' call"
//
// Critical finding: deinit has IMMUTABLE self — cannot call mutating methods.
//   Slab-style cleanup must either: (a) use a consuming method before drop,
//   or (b) use Storage.Heap's own deinit via .initialization tracking.
//
// Date: 2026-02-03

import Core
import Variant

// V1: Growable — convenience init delegates to Core memberwise init
do {
    var g = Container.Ring.Growable<Int>(capacity: 8)
    print("V1 - Growable (delegating init + methods from Variant):")
    print("  isEmpty: \(g.isEmpty) (expected true): \(g.isEmpty ? "CONFIRMED" : "REFUTED")")
    g.push(10)
    g.push(20)
    print("  count: \(g.count) (expected 2): \(g.count == 2 ? "CONFIRMED" : "REFUTED")")
    g.removeAll()
    print("  isEmpty after removeAll: \(g.isEmpty) (expected true): \(g.isEmpty ? "CONFIRMED" : "REFUTED")")
}

// V2: Bounded — convenience init delegates to Core memberwise init
do {
    let b = Container.Ring.Bounded<Int>(capacity: 4)
    print("\nV2 - Bounded (delegating init from Variant):")
    print("  count: \(b.count) (expected 0): \(b.count == 0 ? "CONFIRMED" : "REFUTED")")
}

// V3: Protocol conformance from Variant module
do {
    var g = Container.Ring.Growable<Int>(capacity: 8)
    g.push(1)
    g.push(2)
    g.push(3)
    var drained: [Int] = []
    g.drain { drained.append($0) }
    print("\nV3 - Protocol conformance from Variant:")
    print("  drained: \(drained) (expected [1, 2, 3]): \(drained == [1, 2, 3] ? "CONFIRMED" : "REFUTED")")
    print("  isEmpty after drain: \(g.isEmpty) (expected true): \(g.isEmpty ? "CONFIRMED" : "REFUTED")")
}

// V4: Copyable conformance (declared in Core) works with Variant init
do {
    let g1 = Container.Ring.Growable<Int>(capacity: 4)
    let g2 = g1  // Should compile — Copyable when Element: Copyable
    print("\nV4 - Copyable from Core + Variant init:")
    print("  copy compiles: CONFIRMED")
    _ = g2
}

// V5: Type with deinit in Core, init/methods from Variant
do {
    var d = Container.Ring.Draining<Int>(capacity: 4)
    d.push(42)
    print("\nV5 - Deinit in Core (read-only), init/methods from Variant:")
    print("  count: \(d.count) (expected 1): \(d.count == 1 ? "CONFIRMED" : "REFUTED")")
    // deinit runs when scope exits — can only READ, not mutate
}

// V6: SlabLike — no deinit, explicit cleanup from Variant
do {
    var s = Container.Ring.SlabLike<Int>(capacity: 4)
    s.insert(10)
    s.insert(20)
    print("\nV6 - No deinit, explicit cleanup from Variant:")
    print("  count before cleanup: \(s.count) (expected 2): \(s.count == 2 ? "CONFIRMED" : "REFUTED")")
    s.deinitializeAll()
    print("  count after cleanup: \(s.count) (expected 0): \(s.count == 0 ? "CONFIRMED" : "REFUTED")")
}

print("\n=== Cross-Module Type Declaration Verification Complete ===")
