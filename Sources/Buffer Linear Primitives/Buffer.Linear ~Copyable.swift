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

extension Buffer.Linear where Element: ~Copyable {
    /// Shifts elements left to fill a gap after removal.
    ///
    /// Moves elements from `[gapIndex+1, count)` to `[gapIndex, count-1)`.
    /// The element at `gapIndex` must already be deinitialized.
    ///
    /// - Parameters:
    ///   - elements: Pointer to element storage.
    ///   - gapIndex: Index where the gap exists (element was removed).
    ///   - count: Total number of elements before removal.
    @inlinable
    public static func shiftLeft(
        _ elements: UnsafeMutablePointer<Element>,
        gapIndex: Index<Element>,
        count: Index<Element>.Count
    ) {
        let newCount = count.subtract.saturating(.one)
        guard gapIndex < newCount else { return }

        // Iterate forward: move [gapIndex+1, count) to [gapIndex, count-1)
        (gapIndex..<newCount).forEach { destIndex in
            let srcIndex = destIndex + .one
            unsafe (elements + Index.Offset(__unchecked: (), destIndex)).initialize(
                to: (elements + Index.Offset(__unchecked: (), srcIndex)).move()
            )
        }
    }

    /// Shifts elements right to make room for insertion.
    ///
    /// Moves elements from `[insertionIndex, count)` to `[insertionIndex+1, count+1)`.
    /// After this operation, the slot at `insertionIndex` is uninitialized.
    ///
    /// - Parameters:
    ///   - elements: Pointer to element storage.
    ///   - insertionIndex: Index where new element will be inserted.
    ///   - count: Current number of elements.
    @inlinable
    public static func shiftRight(
        _ elements: UnsafeMutablePointer<Element>,
        insertionIndex: Index<Element>,
        count: Index<Element>.Count
    ) {
        guard insertionIndex < count else { return }

        // Work backwards: move [insertionIndex, count) to [insertionIndex+1, count+1)
        // Start at count-1 and work down to insertionIndex
        var srcCount = count
        while srcCount > Index<Element>.Count(insertionIndex) {
            srcCount = srcCount.subtract.saturating(.one)
            let srcIndex = Index<Element>(srcCount)
            let dstIndex = srcIndex + .one
            unsafe (elements + Index.Offset(__unchecked: (), dstIndex)).initialize(
                to: (elements + Index.Offset(__unchecked: (), srcIndex)).move()
            )
        }
    }

    /// Deinitializes all elements in linear storage.
    ///
    /// - Parameters:
    ///   - elements: Pointer to element storage.
    ///   - count: Number of elements to deinitialize.
    @inlinable
    public static func deinitialize(
        _ elements: UnsafeMutablePointer<Element>,
        count: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        (.zero..<count).forEach { index in
            unsafe (elements + Index.Offset(__unchecked: (), index)).deinitialize(count: 1)
        }
    }

    /// Moves all elements from source to destination.
    ///
    /// - Parameters:
    ///   - source: Pointer to source storage.
    ///   - destination: Pointer to destination storage.
    ///   - count: Number of elements to move.
    @inlinable
    public static func move(
        from source: UnsafeMutablePointer<Element>,
        to destination: UnsafeMutablePointer<Element>,
        count: Index<Element>.Count
    ) {
        guard count > .zero else { return }
        (.zero..<count).forEach { index in
            unsafe (destination + Index.Offset(__unchecked: (), index)).initialize(
                to: (source + Index.Offset(__unchecked: (), index)).move()
            )
        }
    }
}

// MARK: - Linear Arithmetic

extension Buffer.Linear where Element: ~Copyable {
    /// Returns the next index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The successor index.
    /// - Complexity: O(1)
    @inlinable
    public static func successor(
        of index: Index<Element>
    ) -> Index<Element> {
        index + .one
    }

    /// Returns the previous index without wrapping.
    ///
    /// - Parameter index: The current index.
    /// - Returns: The predecessor index.
    /// - Throws: `Ordinal.Error.underflow` if index is zero.
    /// - Complexity: O(1)
    @inlinable
    public static func predecessor(
        of index: Index<Element>
    ) throws(Ordinal.Error) -> Index<Element> {
        try index.predecessor.exact()
    }
}
