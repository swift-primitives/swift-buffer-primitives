// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-buffer open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-buffer project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Buffer {
    /// Namespace for slot-based storage types.
    ///
    /// Provides fixed-capacity, index-addressable storage for ~Copyable elements
    /// with explicit initialization state tracking.
    ///
    /// ## Design
    ///
    /// - `Slots.Bounded`: Bounded capacity, index-based access with occupancy tracking
    ///
    /// ## Use Case
    ///
    /// Slot storage is designed for scenarios requiring:
    /// - O(1) indexed insertion and removal
    /// - Immediate capacity reclamation on removal
    /// - Move-only element support (~Copyable)
    /// - External free-list management
    ///
    /// Unlike ring buffers, slot stores do not maintain ordering. They are
    /// typically paired with a separate order structure (e.g., a ring of indices)
    /// and a free-list for allocation.
    ///
    /// ## Thread Safety
    ///
    /// Not internally synchronized. External synchronization is required for
    /// concurrent access.
    public enum Slots {}
}
