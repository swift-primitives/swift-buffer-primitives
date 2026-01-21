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

public import Index_Primitives

extension Buffer {
    /// Type-safe index for buffer positions.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-buffer index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position represents a byte offset or element offset depending on
    /// the buffer type being accessed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let byteIdx: Buffer.Index<UInt8> = 0
    /// let wordIdx: Buffer.Index<UInt32> = 0
    /// // These cannot be confused at compile time
    /// ```
    public typealias Index<Element> = Index_Primitives.Index<Element>
}
