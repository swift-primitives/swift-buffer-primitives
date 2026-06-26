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
    /// The element ladder's fixture nest (W3-0 hoist, seat-ruled ASK-W2-A).
    public enum Element {}
}

extension Model.Element {
    /// The move-only census-tracked element: identity is `id`; `group` carries a
    /// CONTROLLED hash bucket for hashed-family suites (hash coarser than equality
    /// = lawful collisions on demand; ledger suites leave it 0); `serial` is the
    /// census mint order. Death is recorded exactly once, at the real deinit —
    /// probe arguments, duplicate hand-backs, displaced occupants, and drops all
    /// account identically.
    ///
    /// Domain-protocol conformances (e.g. the hashed families' key bound) live in
    /// the consuming package's test target, not here — this module has no hash
    /// dependency by design.
    public struct Tracked: ~Copyable {
        public let id: Int
        public let group: Int
        public let serial: Int
        private let census: Model.Census

        public init(id: Int, group: Int = 0, census: Model.Census) {
            self.id = id
            self.group = group
            self.census = census
            self.serial = census.mint()
        }

        deinit {
            census.record(death: serial)
        }
    }
}
