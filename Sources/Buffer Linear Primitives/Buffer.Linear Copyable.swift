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

public import Buffer_Primitives_Core

// MARK: - Copyable Bulk Operations

extension Buffer.Linear where Element: Copyable {
    /// Copies all elements from source to destination.
    ///
    /// - Parameters:
    ///   - source: Pointer to source storage.
    ///   - destination: Pointer to destination storage.
    ///   - count: Number of elements to copy.
    @inlinable
    public static func copy(
        from source: UnsafePointer<Element>,
        to destination: UnsafeMutablePointer<Element>,
        count: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        (.zero..<count).forEach { index in
            unsafe (destination + Index.Offset(__unchecked: (), index)).initialize(
                to: (source + Index.Offset(__unchecked: (), index)).pointee
            )
        }
    }
}
