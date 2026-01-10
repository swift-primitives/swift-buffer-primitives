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
    /// Provides `Fixed` and `Growable` ring buffer variants for ~Copyable elements,
    /// plus `Optional` for backward compatibility with array-backed storage.
    ///
    /// ## Design
    ///
    /// - `Ring.Fixed`: Bounded capacity, returns rejected element on overflow
    /// - `Ring.Growable`: Unbounded, grows automatically
    /// - `Ring.Optional`: Legacy array-backed ring (requires Copyable elements)
    ///
    /// ## Thread Safety
    ///
    /// None of these types are internally synchronized. External synchronization
    /// is required for concurrent access.
    public enum Ring {}
}
