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
    /// Bounded-capacity buffer with LIFO semantics and copy-on-write.
    ///
    /// `Bounded` provides O(1) push/pop operations with a bounded capacity.
    /// Unlike stdlib `Array`, it never reallocates after initialization.
    ///
    /// ## API
    ///
    /// Operations use typed throws as the primary API:
    ///
    /// ```swift
    /// var buffer = Buffer.Bounded<Int>(capacity: 10)
    ///
    /// // Primary API (typed throws)
    /// try buffer.push(1)           // throws .full if at capacity
    /// let value = try buffer.pop() // throws .empty if empty
    ///
    /// // Explicit error handling (one catch, then switch)
    /// do {
    ///     try buffer.push(element)
    /// } catch {
    ///     switch error {
    ///     case .full: // handle full
    ///     case .empty: // handle empty
    ///     }
    /// }
    ///
    /// // Unchecked (for invariant-protected paths)
    /// buffer.push(__unchecked: (), element)
    ///
    /// // Peek
    /// if let top = buffer.top { ... }
    /// ```
    ///
    /// ## Invariants
    ///
    /// The following invariants are always maintained:
    /// - `0 <= count <= capacity`
    /// - `pointer != nil` iff `capacity > 0`
    /// - Elements are initialized exactly in `0..<count`
    /// - Mutations only occur after `ensureUnique()`
    ///
    /// ## Copy-on-Write
    ///
    /// Multiple copies share storage until mutation occurs.
    /// Mutation triggers a copy only when storage is shared.
    ///
    /// ## Thread Safety
    ///
    /// The type is `Sendable` when `Element: Sendable`, meaning it can be
    /// transferred across concurrency domains. However, it is NOT thread-safe
    /// for concurrent mutation. External synchronization is required.
    public struct Bounded<Element> {
        @usableFromInline
        var storage: Storage

        /// The fixed capacity of the buffer.
        public let capacity: Int

        /// Creates a fixed buffer with the given capacity.
        ///
        /// - Parameter capacity: Maximum number of elements. Must be non-negative.
        @inlinable
        public init(capacity: Int) {
            precondition(capacity >= 0, "Capacity must be non-negative")
            self.capacity = capacity
            self.storage = Storage(capacity: capacity)
        }

        /// The current number of elements in the buffer.
        @inlinable
        public var count: Int { storage.count }

        /// Whether the buffer is empty.
        @inlinable
        public var isEmpty: Bool { storage.count == 0 }

        /// Whether the buffer is at capacity.
        @inlinable
        public var isFull: Bool { storage.count >= capacity }
    }
}

// MARK: - Storage

extension Buffer.Bounded {
    /// Reference-counted storage for COW semantics.
    @usableFromInline
    final class Storage {
        @usableFromInline
        var pointer: UnsafeMutablePointer<Element>?

        @usableFromInline
        var count: Int

        @usableFromInline
        let capacity: Int

        @usableFromInline
        init(capacity: Int) {
            self.capacity = capacity
            self.count = 0
            if capacity > 0 {
                self.pointer = .allocate(capacity: capacity)
            } else {
                self.pointer = nil
            }
        }

        /// Copy constructor for COW.
        @usableFromInline
        init(copying other: Storage) {
            self.capacity = other.capacity
            self.count = other.count
            if other.capacity > 0, let otherPointer = other.pointer {
                self.pointer = .allocate(capacity: other.capacity)
                self.pointer!.initialize(from: otherPointer, count: other.count)
            } else {
                self.pointer = nil
            }
        }

        deinit {
            if let pointer = pointer {
                pointer.deinitialize(count: count)
                pointer.deallocate()
            }
        }
    }
}

// MARK: - COW Helper

extension Buffer.Bounded {
    /// Ensures storage is uniquely referenced before mutation.
    @inlinable
    mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(copying: storage)
        }
    }
}

// MARK: - Push (Primary Throwing API)

extension Buffer.Bounded {
    /// Pushes an element to the buffer.
    ///
    /// - Parameter element: The element to push.
    /// - Throws: `Buffer.Bounded.Error.full` if the buffer is at capacity.
    /// - Complexity: O(1).
    @inlinable
    public mutating func push(_ element: Element) throws(Error) {
        guard storage.count < capacity else {
            throw .full
        }
        ensureUnique()
        storage.pointer!.advanced(by: storage.count).initialize(to: element)
        storage.count += 1

        // Memory invariant: elements in [0..<count) initialized, [count..<capacity) uninitialized.
        // After push, newly incremented count marks the boundary correctly.
        #if DEBUG
        assert(storage.count >= 1 && storage.count <= capacity, "Count invariant violated after push")
        #endif
    }

    /// Pushes an element to the buffer, trapping if full.
    ///
    /// Use this when overflow indicates a logic error (invariant-protected paths).
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - element: The element to push.
    /// - Precondition: Buffer must not be full.
    /// - Complexity: O(1).
    @inlinable
    public mutating func push(__unchecked: Void, _ element: Element) {
        precondition(storage.count < capacity, "Buffer overflow")
        ensureUnique()
        storage.pointer!.advanced(by: storage.count).initialize(to: element)
        storage.count += 1

        // Memory invariant: elements in [0..<count) initialized, [count..<capacity) uninitialized.
        #if DEBUG
        assert(storage.count >= 1 && storage.count <= capacity, "Count invariant violated after push")
        #endif
    }
}

// MARK: - Pop (Primary Throwing API)

extension Buffer.Bounded {
    /// Pops the most recently pushed element (LIFO).
    ///
    /// - Returns: The removed element.
    /// - Throws: `Buffer.Bounded.Error.empty` if the buffer is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func pop() throws(Error) -> Element {
        guard storage.count > 0 else {
            throw .empty
        }
        ensureUnique()
        storage.count -= 1

        // Memory invariant: after decrementing count, position [count] will be deinitialized via .move().
        // Elements in [0..<count) remain initialized, [count..<capacity) become uninitialized.
        #if DEBUG
        assert(storage.count >= 0 && storage.count < capacity, "Count invariant violated after pop")
        #endif

        return storage.pointer!.advanced(by: storage.count).move()
    }
}

// MARK: - Peek

extension Buffer.Bounded {
    /// The most recently pushed element without removing it.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var top: Element? {
        guard storage.count > 0 else { return nil }
        // Invariant: count > 0 implies pointer != nil (capacity > 0)
        #if DEBUG
        precondition(storage.pointer != nil, "Invariant violation: non-zero count with nil pointer")
        #endif
        return storage.pointer!.advanced(by: storage.count - 1).pointee
    }
}

// MARK: - Remove All

extension Buffer.Bounded {
    /// Removes all elements from the buffer.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func removeAll() {
        guard storage.count > 0 else { return }
        ensureUnique()
        storage.pointer!.deinitialize(count: storage.count)
        storage.count = 0
    }
}

// MARK: - Subscript

extension Buffer.Bounded {
    /// Accesses the element at the specified index.
    ///
    /// Index 0 is the bottom (oldest), `count - 1` is the top (newest).
    ///
    /// - Parameter index: The index of the element.
    /// - Precondition: `index` must be in `0..<count`.
    /// - Complexity: O(1).
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < storage.count, "Index out of bounds")
            return storage.pointer![index]
        }
        set {
            precondition(index >= 0 && index < storage.count, "Index out of bounds")
            ensureUnique()
            storage.pointer![index] = newValue
        }
    }
}

// MARK: - Iteration

extension Buffer.Bounded {
    /// Iterates over all elements from bottom to top.
    ///
    /// - Parameter body: A closure called with each element.
    /// - Complexity: O(n).
    @inlinable
    public func forEach(_ body: (Element) throws -> Void) rethrows {
        let count = storage.count
        guard count > 0 else { return }
        // Invariant: count > 0 implies pointer != nil
        #if DEBUG
        precondition(storage.pointer != nil, "Invariant violation: non-zero count with nil pointer")
        #endif
        let pointer = storage.pointer!
        for i in 0..<count {
            try body(pointer[i])
        }
    }
}

// MARK: - Internal Identity (for COW testing)

extension Buffer.Bounded {
    /// Storage identity for COW testing.
    ///
    /// Access via `@testable import Buffer`.
    @usableFromInline
    internal var _identity: ObjectIdentifier {
        ObjectIdentifier(storage)
    }
}

// MARK: - Conditional Conformances

extension Buffer.Bounded: Sendable where Element: Sendable {}

extension Buffer.Bounded.Storage: @unchecked Sendable where Element: Sendable {}

extension Buffer.Bounded: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        guard lhs.count > 0 else { return true }  // Both empty
        // Invariant: count > 0 implies pointer != nil
        let lp = lhs.storage.pointer!
        let rp = rhs.storage.pointer!
        for i in 0..<lhs.count {
            if lp[i] != rp[i] { return false }
        }
        return true
    }
}
