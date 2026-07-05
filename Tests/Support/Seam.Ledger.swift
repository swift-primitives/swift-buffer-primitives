// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
// `Index_Primitives` is used only in the (non-inlinable) body after M7 dropped the
// `where S.Count == Index<S.Element>.Count` signature clause — internal import suffices.
import Index_Primitives

extension Seam {
    /// THE SEAM LEDGER LAWS — the contract `Array`-tier generic mutations rely on but the
    /// type system cannot express: a COLUMN's seam operations keep `Buffer.Protocol.count`
    /// honest (`initialize(at:to:)` increments by one; `move(at:)` decrements by one; the
    /// element subscript leaves it unchanged; `capacity` is untouched by all three).
    ///
    /// Every type that conforms to BOTH seam protocols and is consumed as an ADT column
    /// MUST pass these laws from its own test suite:
    ///
    /// ```swift
    /// let violations = Seam.Ledger.violations(
    ///     makeEmpty: { MyColumn(minimumCapacity: Index<Int>.Count(2)) },
    ///     element: { $0 }
    /// )
    /// #expect(violations.isEmpty)
    /// ```
    public enum Ledger {
        /// Runs the ledger laws against a fresh column and returns human-readable
        /// descriptions of every violated law (empty = lawful).
        ///
        /// - Parameters:
        ///   - makeEmpty: Constructs an EMPTY column with capacity ≥ 2.
        ///   - element: Produces a distinguishable element for a given ordinal.
        public static func violations<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>(
            makeEmpty: () -> S,
            element: (Int) -> S.Element
        ) -> [String] {
            var found: [String] = []
            var column = makeEmpty()

            let zero = Index<S.Element>.Count(UInt(0))
            let one = Index<S.Element>.Count(UInt(1))
            let two = Index<S.Element>.Count(UInt(2))
            let slot0 = Index<S.Element>(Ordinal(UInt(0)))
            let slot1 = Index<S.Element>(Ordinal(UInt(1)))

            guard column.capacity >= two else {
                return ["precondition: makeEmpty() must provide capacity >= 2 (got \(column.capacity))"]
            }
            if column.count != zero {
                found.append("law 0: a fresh column must report count == 0 (got \(column.count))")
            }
            let capacityBefore = column.capacity

            column.initialize(at: slot0, to: element(0))
            if column.count != one {
                found.append("law 1: initialize(at:to:) must increment count by one (got \(column.count), expected 1)")
            }
            column.initialize(at: slot1, to: element(1))
            if column.count != two {
                found.append("law 1: initialize(at:to:) must increment count by one (got \(column.count), expected 2)")
            }

            column[slot0] = element(2)
            if column.count != two {
                found.append("law 2: the element subscript must leave count unchanged (got \(column.count), expected 2)")
            }

            _ = column.move(at: slot1)
            if column.count != one {
                found.append("law 3: move(at:) must decrement count by one (got \(column.count), expected 1)")
            }
            _ = column.move(at: slot0)
            if column.count != zero {
                found.append("law 3: move(at:) must decrement count by one (got \(column.count), expected 0)")
            }

            if column.capacity != capacityBefore {
                found.append("law 4: seam element ops must not change capacity (was \(capacityBefore), now \(column.capacity))")
            }
            return found
        }
    }
}
