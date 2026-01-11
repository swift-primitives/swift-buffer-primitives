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
    /// Namespace for ring buffer types.
    ///
    /// Provides `Bounded` and `Unbounded` ring buffer variants for ~Copyable elements.
    ///
    /// ## Design
    ///
    /// - `Ring.Bounded`: Bounded capacity, returns rejected element on overflow
    /// - `Ring.Unbounded`: Unbounded, grows automatically
    ///
    /// ## Thread Safety
    ///
    /// None of these types are internally synchronized. External synchronization
    /// is required for concurrent access.
    public enum Ring {}
}
