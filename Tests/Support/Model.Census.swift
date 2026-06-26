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

extension Model {
    /// The teardown census: every fixture element records its birth and its death
    /// here by SERIAL (mint order), so exactness oracles can assert per-op death
    /// counts and end-of-scope birth/death multiset equality — the model-stream
    /// teardown discipline (W3-0 hoist, seat-ruled ASK-W2-A).
    ///
    /// One instance per stream run (single-threaded); never share across tests.
    public final class Census {
        public private(set) var born: [Int] = []
        public private(set) var died: [Int] = []

        public init() {}

        /// Registers a birth; returns the fixture's serial.
        public func mint() -> Int {
            let serial = born.count
            born.append(serial)
            return serial
        }

        public func record(death serial: Int) {
            died.append(serial)
        }

        /// Every mint died exactly once (multiset equality over serials).
        public var isExact: Bool {
            born.sorted() == died.sorted()
        }
    }
}
