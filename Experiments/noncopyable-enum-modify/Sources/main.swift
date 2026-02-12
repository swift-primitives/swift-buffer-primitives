// MARK: - Noncopyable Enum _modify Validation
// Purpose: Validate the claim that Swift _modify coroutines cannot yield
//          mutable references into enum payloads for ~Copyable associated
//          values, while Optional._modify CAN yield &optional! for ~Copyable
//          wrapped values.
// Hypothesis: Optional has special compiler support for _modify that arbitrary
//             enums do not. An enum-based Small buffer storage would lose
//             zero-cost mutable access.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Optional._modify can yield &optional! for ~Copyable
//         wrapped values (V1, V8). All enum _modify approaches fail: partial
//         reinit rejected (V2, V6), self consumed across yield point (V7).
//         Enum reads work via SE-0432 borrowing switch (V5). Enum mutation
//         requires full self reinit in mutating func (V3), losing _modify.
//         Root cause validated against swiftlang/swift compiler source:
//         Optional uses unchecked_take_enum_data_addr (non-destructive for
//         single-payload enums); multi-payload enums lack this guarantee.
// Date: 2026-02-12

// =============================================================================
// MARK: - Setup: Minimal ~Copyable type
// =============================================================================

struct Resource: ~Copyable {
    var value: Int

    init(_ value: Int) {
        self.value = value
    }

    mutating func increment() {
        value += 1
    }
}

enum Storage: ~Copyable {
    case inline(Resource)
    case heap(Resource)
}

// =============================================================================
// MARK: - Variant 1: Optional _read + _modify with force-unwrap (baseline)
// Hypothesis: COMPILES — Optional has special compiler support for yielding
//             mutable references into .some payload via &optional!.
// Result: CONFIRMED — compiles and runs. Output: 11
// =============================================================================

struct V1_OptionalHolder: ~Copyable {
    var _resource: Resource?

    var resource: Resource {
        _read {
            yield _resource!
        }
        _modify {
            yield &_resource!
        }
    }
}

func testV1() {
    var holder = V1_OptionalHolder(_resource: Resource(10))
    holder.resource.increment()
    print("V1 Optional _read/_modify: \(holder.resource.value)")
    // Expected: 11
}

// =============================================================================
// MARK: - Variant 2: Enum — mutating func with switch var + partial reassign
// Hypothesis: FAILS — switch with var binding consumes self; reassigning
//             _storage is "partial reinitialization" which is forbidden.
// Result: CONFIRMED — error: "cannot partially reinitialize 'self'"
// =============================================================================

// UNCOMMENT TO TEST (expected: "cannot partially reinitialize 'self'"):
//
// struct V2_EnumPartialReinit: ~Copyable {
//     var _storage: Storage
//
//     mutating func incrementHeap() {
//         switch _storage {
//         case .heap(var res):
//             res.increment()
//             _storage = .heap(res)  // partial reinit error
//         case .inline(var res):
//             res.increment()
//             _storage = .inline(res)
//         }
//     }
// }

// =============================================================================
// MARK: - Variant 3: Enum — mutating func with switch var + full self reinit
// Hypothesis: COMPILES — reassigning `self = Self(...)` is full reinit,
//             which IS allowed after consumption.
// Result: CONFIRMED — compiles and runs. Output: 21
// =============================================================================

struct V3_EnumFullReinit: ~Copyable {
    var _storage: Storage

    init(_storage: consuming Storage) {
        self._storage = _storage
    }

    mutating func incrementHeap() {
        switch _storage {
        case .heap(var res):
            res.increment()
            self = V3_EnumFullReinit(_storage: .heap(res))
        case .inline(var res):
            res.increment()
            self = V3_EnumFullReinit(_storage: .inline(res))
        }
    }
}

func testV3() {
    var holder = V3_EnumFullReinit(_storage: .heap(Resource(20)))
    holder.incrementHeap()
    switch holder._storage {
    case .heap(let res):
        print("V3 Enum full reinit: \(res.value)")
    case .inline(let res):
        print("V3 Enum full reinit (inline): \(res.value)")
    }
    // Expected: 21
}

// =============================================================================
// MARK: - Variant 4: Enum — _read with guard case (consumes)
// Hypothesis: FAILS — `guard case .heap(let res) = _storage` consumes
//             _storage even with let binding. Unlike `switch`, `guard case`
//             does not borrow per SE-0432.
// Result: CONFIRMED — error: "'self' is borrowed and cannot be consumed"
// =============================================================================

// UNCOMMENT TO TEST (expected: "'self' is borrowed and cannot be consumed"):
//
// struct V4_EnumGuardCaseRead: ~Copyable {
//     var _storage: Storage
//
//     var heapResource: Resource {
//         _read {
//             guard case .heap(let res) = _storage else { fatalError() }
//             yield res
//         }
//     }
// }

// =============================================================================
// MARK: - Variant 5: Enum — _read with switch (borrows per SE-0432)
// Hypothesis: COMPILES — switch with let binding borrows per SE-0432.
// Result: CONFIRMED — compiles and runs. Output: 30
// =============================================================================

struct V5_EnumSwitchRead: ~Copyable {
    var _storage: Storage

    var heapValue: Int {
        switch _storage {
        case .heap(let res): return res.value
        case .inline(let res): return res.value
        }
    }
}

func testV5() {
    let holder = V5_EnumSwitchRead(_storage: .heap(Resource(30)))
    print("V5 Enum switch _read: \(holder.heapValue)")
    // Expected: 30
}

// =============================================================================
// MARK: - Variant 6: Enum — _modify with guard case var + reassign
// Hypothesis: FAILS — same partial reinit problem as V2, plus _modify
//             context still doesn't allow consuming self via guard case.
// Result: CONFIRMED — errors: "consumed here" + "cannot partially reinitialize"
// =============================================================================

// UNCOMMENT TO TEST:
//
// struct V6_EnumModifyGuardCase: ~Copyable {
//     var _storage: Storage
//
//     var heapResource: Resource {
//         _read {
//             switch _storage {
//             case .heap(let res): yield res
//             case .inline(let res): yield res
//             }
//         }
//         _modify {
//             guard case .heap(var res) = _storage else { fatalError() }
//             yield &res
//             _storage = .heap(res)  // partial reinit after consumption
//         }
//     }
// }

// =============================================================================
// MARK: - Variant 7: Enum — _modify with full self reinit
// Hypothesis: MAY COMPILE — _modify allows mutation, and full self reinit
//             is allowed. But yield &res yields a LOCAL (extracted copy),
//             not a reference into the enum payload. Mutation goes to the
//             local, then we reconstruct. This "works" but is NOT zero-cost.
// Result: REFUTED — error: "missing reinitialization of inout parameter
//         'self' after consume". Self is consumed at the switch, and remains
//         consumed DURING the yield suspension. The compiler requires self
//         to be valid throughout the yield point.
// =============================================================================

// UNCOMMENT TO TEST (expected: "missing reinitialization of inout parameter
// 'self' after consume" — the switch consumes _storage, and self is in a
// consumed state DURING the yield point. The caller's mutation happens while
// self is invalid. Reinit comes AFTER yield returns, but the compiler requires
// self to be valid throughout the yield suspension.):
//
// struct V7_EnumModifyFullReinit: ~Copyable {
//     var _storage: Storage
//
//     init(_storage: consuming Storage) {
//         self._storage = _storage
//     }
//
//     var heapResource: Resource {
//         _read {
//             switch _storage {
//             case .heap(let res): yield res
//             case .inline(let res): yield res
//             }
//         }
//         _modify {
//             switch _storage {
//             case .heap(var res):
//                 yield &res
//                 self = V7_EnumModifyFullReinit(_storage: .heap(res))
//             case .inline(var res):
//                 yield &res
//                 self = V7_EnumModifyFullReinit(_storage: .inline(res))
//             }
//         }
//     }
// }
//
// func testV7() {
//     var holder = V7_EnumModifyFullReinit(_storage: .heap(Resource(40)))
//     holder.heapResource.increment()
//     print("V7 Enum _modify full reinit: \(holder.heapResource.value)")
//     // Expected: 41
// }

// =============================================================================
// MARK: - Variant 8: Optional — switch for _read, &optional! for _modify
// Hypothesis: COMPILES — this is the actual pattern used in buffer-primitives.
//             Demonstrates that Optional gets both borrowing reads (switch) AND
//             zero-cost mutation (&optional!), a combination impossible with enums.
// Result: CONFIRMED — compiles and runs. Output: 50, 51
// =============================================================================

struct V8_OptionalBestOfBoth: ~Copyable {
    var _resource: Resource?

    var resource: Resource {
        _read {
            switch _resource {
            case .some(let res): yield res
            case .none: fatalError("nil")
            }
        }
        _modify {
            yield &_resource!
        }
    }
}

func testV8() {
    var holder = V8_OptionalBestOfBoth(_resource: Resource(50))
    print("V8 Optional switch read: \(holder.resource.value)")
    holder.resource.increment()
    print("V8 After _modify increment: \(holder.resource.value)")
    // Expected: 50, then 51
}

// =============================================================================
// MARK: - Execution
// =============================================================================

testV1()
testV3()
testV5()
// testV7()  // commented out — does not compile
testV8()

// =============================================================================
// MARK: - Results Summary
//
// V1: CONFIRMED — Optional _read/_modify with &optional! works (zero-cost)
// V2: CONFIRMED — Enum partial reinit REJECTED by compiler
// V3: CONFIRMED — Enum full self reinit works (but costs extra moves)
// V4: CONFIRMED — guard case consumes in _read (unlike switch which borrows)
// V5: CONFIRMED — Enum switch _read borrows correctly (SE-0432)
// V6: CONFIRMED — Enum _modify with guard case: partial reinit REJECTED
// V7: REFUTED  — Enum _modify with full reinit ALSO fails: self consumed
//                across yield point ("missing reinitialization of inout
//                parameter 'self' after consume")
// V8: CONFIRMED — Optional: switch _read + &optional! _modify (best of both)
//
// CONCLUSION: Optional has compiler support that arbitrary enums lack.
// &optional! in _modify yields a reference INTO the Optional's storage
// without consuming self. For enums, any attempt to extract the payload
// (via switch var or guard case var) CONSUMES self, and self must be
// valid during _modify's yield suspension. This is a fundamental
// language limitation, not a missing feature — the compiler cannot
// know which enum case is active without consuming the discriminant.
//
// COMPILER-LEVEL ROOT CAUSE (validated against swiftlang/swift source):
//
// Optional's force-unwrap (`&optional!`) lowers to `ForceOptionalObjectComponent`
// in SILGenLValue.cpp, which emits the `unchecked_take_enum_data_addr` SIL
// instruction. This instruction projects a mutable address directly into the
// Optional's .some payload WITHOUT consuming the enum. The compiler comment
// states: "safe to apply to Optional, because it is a single-payload enum."
//
// For single-payload enums (like Optional), the discriminant is stored in
// spare bits OUTSIDE the payload — projecting into the payload does not
// disturb the discriminant. For multi-payload enums, discriminant bits may
// overlap with payload data, making the same projection destructive (the
// `UncheckedTakeEnumDataAddrInst` has an `isDestructive()` flag for this).
//
// This is why no general `_modify` into enum payloads exists: the compiler
// cannot safely project a mutable address into an arbitrary enum case without
// potentially corrupting the discriminant. The `MoveOnlyPartialReinitialization`
// experimental feature exists but only applies to structs and tuples, not enums.
// A TODO in MoveOnlyAddressCheckerUtils.cpp reads: "Revisit this when we
// introduce deinits on enums."
//
// Source references:
//   lib/SILGen/SILGenLValue.cpp:966-987   — ForceOptionalObjectComponent
//   lib/SILGen/SILGenLValue.cpp:550-593   — getPayloadOfOptionalValue
//   include/swift/SIL/SILInstruction.h:7243 — UncheckedTakeEnumDataAddrInst
//   lib/SILOptimizer/Mandatory/MoveOnlyAddressCheckerUtils.cpp:1866 — TODO
// =============================================================================
