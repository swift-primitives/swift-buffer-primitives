// MARK: - V03: ~Escapable Values in Deinit
// Purpose: Test approaches to use ~Escapable Property.View types in deinit.
//          Deinit has an immutable `self`, so ~Escapable values that borrow
//          stored properties face lifetime-dependent-value-escapes-scope errors.
// Hypothesis: @_unsafeNonescapableResult on get accessor enables ~Escapable in deinit
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — @_unsafeNonescapableResult on `get` accessor (not `_read`)
//         enables ~Escapable values in deinit. Combined with `mutating _modify`
//         for tracked operations. This is THE solution for Property.View accessors.
//
//         REFUTED: _read accessor (V1-V5, V8, V10, V13) — "lifetime-dependent
//                  value escapes its scope"
//         CONFIRMED: get + @_unsafeNonescapableResult (V17, V18) — works
//         COMPILER BUG: @_unsafeNonescapableResult on _read (V14, V15) — signal 6
//
// Date: 2026-03-21
//
// Consolidates: escapable-deinit-lifetime (18 variants)
// Supports: escapable-deinit-lifetime.md, Property.View accessor pattern

// --- Setup: Simulated Property.View pattern ---

struct Owner: ~Copyable {
    var _value: Int

    init(_ value: Int) { self._value = value }

    // --- REFUTED approach: _read yields @guaranteed (carries lifetime) ---
    // var view_read: BorrowedView {
    //     _read {
    //         yield BorrowedView(value: _value)  // ERROR in deinit
    //     }
    // }

    // --- CONFIRMED approach: get returns @owned (no lifetime dependence) ---

    @_unsafeNonescapableResult
    var view: View {
        get { View(value: _value) }
    }

    // Mutating path still uses _modify for tracked operations
    var mutableView: View {
        @_unsafeNonescapableResult
        get { View(value: _value) }
        _modify {
            var v = View(value: _value)
            yield &v
            _value = v.value
        }
    }

    deinit {
        // This works because `view` uses `get` (returns @owned)
        let v = view
        print("  Owner deinit: value=\(v.value)")
    }
}

struct View: ~Escapable {
    var value: Int

    @_unsafeNonescapableResult
    init(value: Int) {
        self.value = value
    }
}

// --- V9: withUnsafePointer closure (alternative that also works in deinit) ---

struct V9_Closure: ~Copyable {
    var _value: Int

    init(_ value: Int) { self._value = value }

    func withView(_ body: (Int) -> Void) {
        body(_value)
    }

    deinit {
        withView { value in
            print("  V9 deinit: value=\(value)")
        }
    }
}

// --- Tests ---

func testOwner() {
    print("=== V17/V18: get + @_unsafeNonescapableResult ===")
    do {
        var owner = Owner(42)
        print("  Read: \(owner.view.value)")
        owner.mutableView.value = 99
        print("  After modify: \(owner.mutableView.value)")
        // deinit prints the final value
    }
}

func testV9() {
    print("\n=== V9: withUnsafePointer closure ===")
    do {
        let _ = V9_Closure(77)
        // deinit uses closure pattern
    }
}

testOwner()
testV9()

print("\nSUMMARY:")
print("  `_read` in deinit: BLOCKED — yields @guaranteed, carries lifetime")
print("  `get` + @_unsafeNonescapableResult: WORKS — returns @owned, no lifetime")
print("  `_read` + @_unsafeNonescapableResult: COMPILER CRASH (signal 6)")
print("  withUnsafePointer closure: WORKS — alternative when _read not needed")
print("\n  THE SOLUTION: @_unsafeNonescapableResult on `get` accessor")
print("  Combined with `mutating _modify` for tracked mutation paths.")
