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

// MARK: - Ring Arithmetic (Core)

// These operations are in Core because they are required by deinit.
// They delegate to Modular operations from Cyclic_Index_Primitives.

extension Buffer.Ring where Element: ~Copyable {
    /// Deinitializes elements in a ring buffer.
    ///
    /// Elements are visited from `head` position with wrapping at capacity.
    ///
    /// - Parameters:
    ///   - elements: Pointer to element storage.
    ///   - head: Physical index of first element.
    ///   - count: Number of elements to deinitialize.
    ///   - capacity: Buffer capacity (for wrapping).
    @inlinable
    public static func deinitialize(
        _ elements: UnsafeMutablePointer<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        var index = head
        (.zero..<count).forEach { _ in
            unsafe (elements + Index.Offset(__unchecked: (), index)).deinitialize(count: 1)
            index = successor(of: index, wrapping: capacity)
        }
    }
}

extension Buffer.Ring where Element: ~Copyable {
    /// Advances an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The successor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func successor(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Modular.successor(of: index, capacity: capacity)
    }
    
    /// Retreats an index by one position, wrapping at capacity.
    ///
    /// - Parameters:
    ///   - index: The current index.
    ///   - capacity: The buffer capacity (must be positive).
    /// - Returns: The predecessor index wrapped to `0..<capacity`.
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor(
        of index: Index<Element>,
        wrapping capacity: Index<Element>.Count
    ) -> Index<Element> {
        Modular.predecessor(of: index, capacity: capacity)
    }
}
