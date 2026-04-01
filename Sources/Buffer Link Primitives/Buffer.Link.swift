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

extension Buffer where Element: ~Copyable {

    /// Pure link topology discipline.
    ///
    /// Provides O(1) linked-list operations parametric over node access.
    /// Does not allocate, deallocate, or touch elements — only manages
    /// prev/next indices via the `nodeAt` closure.
    ///
    /// ## Design
    ///
    /// `Buffer.Link` factors out the link algebra that is common to all
    /// linked-list-like data structures — whether backed by a pool, arena,
    /// or inline storage. Consumers compose `Buffer.Link` with their own
    /// allocation backend:
    ///
    /// - `Buffer.Linked`: delegates link operations to `Buffer.Link`,
    ///   handles allocation via `Storage<Node>.Pool`
    /// - Timer wheels, LRU caches, scheduler queues: use `Buffer.Link`
    ///   directly with `Buffer.Arena` or other allocators
    ///
    /// ## Link Convention
    ///
    /// - `links[0]` = next (toward tail)
    /// - `links[1]` = prev (toward head, when N >= 2)
    /// - Sentinel value marks end-of-list (no Optional overhead)
    ///
    /// - Parameter N: Link count per node. 1 = singly-linked, 2 = doubly-linked.
    public enum Link<let N: Int> {}
}
