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

// MARK: - Bitset

/// Internal word-backed bitset for occupancy tracking.
///
/// Used by `Buffer.Slots.Bounded` for efficient slot occupancy tracking.
/// Not a public primitive; internal implementation detail.
///
/// ## Design
///
/// - Uses `UnsafeMutablePointer<UInt>` for word storage
/// - Bit-packed: 64 slots per word on 64-bit platforms
/// - O(1) get/set by index
/// - Memory: ~1 bit per slot (vs 1+ byte with Bool array)
@usableFromInline
package struct Bitset: ~Copyable {
    @usableFromInline
    package var _words: UnsafeMutablePointer<UInt>

    @usableFromInline
    package let _wordCount: Int

    /// Creates a bitset with the specified capacity.
    ///
    /// All bits are initially cleared (false).
    ///
    /// - Parameter capacity: The number of bits to track.
    @inlinable
    package init(capacity: Int) {
        let wordCount = (capacity + UInt.bitWidth - 1) / UInt.bitWidth
        self._wordCount = wordCount
        unsafe self._words = .allocate(capacity: wordCount)
        unsafe _words.initialize(repeating: 0, count: wordCount)
    }

    /// Gets or sets the bit at the specified index.
    ///
    /// - Parameter index: The bit index.
    /// - Returns: `true` if the bit is set, `false` otherwise.
    @inlinable
    package subscript(index: Int) -> Bool {
        get {
            let (word, bit) = index.quotientAndRemainder(dividingBy: UInt.bitWidth)
            return unsafe (_words[word] & (1 << bit)) != 0
        }
        nonmutating set {
            let (word, bit) = index.quotientAndRemainder(dividingBy: UInt.bitWidth)
            if newValue {
                unsafe _words[word] |= (1 << bit)
            } else {
                unsafe _words[word] &= ~(1 << bit)
            }
        }
    }

    /// Clears all bits to false.
    @inlinable
    package func clearAll() {
        for i in 0..<_wordCount {
            unsafe _words[i] = 0
        }
    }

    deinit {
        unsafe _words.deallocate()
    }
}
