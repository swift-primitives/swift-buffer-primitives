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
public import Memory_Primitives
public import Storage_Primitives

// MARK: - Buffer (Namespace)

/// Namespace for buffer primitives.
///
/// `Buffer` provides circular and linear buffer types with ~Copyable support
/// for use across I/O and encoding/decoding libraries.
///
/// ## Variants
///
/// - ``Buffer/Ring``: Circular buffer types (bounded and unbounded)
/// - ``Buffer/Linear``: Contiguous buffer operations
/// - ``Buffer/Slots``: Index-addressable slot storage
/// - ``Buffer/Growth``: Growth policy configuration
public enum Buffer<Element: ~Copyable>: Copyable {
    /// Type-safe index for buffer positions.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-buffer index confusion.
    public typealias Index = Index_Primitives.Index<Element>

    // MARK: - Linear (Namespace)

    /// Namespace for linear buffer types and operations.
    ///
    /// Provides contiguous, forward-sequential storage discipline. Elements occupy
    /// positions 0..<count with no wrapping. Used by Array, Stack, and containers
    /// needing random-access semantics.
    public enum Linear {

    }

    // MARK: - Ring (Unbounded Circular Buffer)

    /// Unbounded circular buffer for ~Copyable elements.
    ///
    /// A FIFO ring buffer that automatically grows when capacity is exhausted.
    /// Uses move semantics for elements, supporting non-copyable types.
    ///
    /// ## Design
    ///
    /// - Backing storage: Nested `Storage` class (wraps `Storage<Element>` from storage-primitives)
    /// - Slot tracking: Ring header within Storage for head/tail/count
    /// - Growth: configurable via `Buffer.Growth.Policy` (default: doubling)
    /// - FIFO ordering preserved across growth
    ///
    /// ## Copyable Conformance
    ///
    /// When `Element: Copyable`, `Buffer.Ring` is also `Copyable` with
    /// copy-on-write semantics. Copies share storage until mutation.
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe. External synchronization required for concurrent access.
    @safe
    public struct Ring: ~Copyable {
        // MARK: - Nested Storage

        /// Internal storage class for ring buffer.
        ///
        /// Wraps `Storage<Element>` and handles ring-aware element deinitialization.
        /// Nested inside `Ring` to inherit the `Element: ~Copyable` constraint.
        @usableFromInline
        package final class _Storage {
            @usableFromInline
            package var elements: Storage_Primitives.Storage.Dynamic<Element>

            @usableFromInline
            package var header: Header

            @usableFromInline
            package var capacity: Index.Count

            @usableFromInline
            package init(elements: Storage_Primitives.Storage.Dynamic<Element>, capacity: Index.Count) {
                self.elements = elements
                self.header = Header()
                self.capacity = capacity
            }

            deinit {
                guard header.count > .zero else { return }
                // Deinitialize elements in ring order
                var index = header.head
                (Index.zero..<header.count).forEach { _ in
                    _ = elements.move(at: index)
                    index = Ring.successor(of: index, wrapping: capacity)
                }
                // Prevent elements.deinit from double-deinitializing
                elements.initialization = .empty
            }
        }

        @usableFromInline
        package var _storage: _Storage?

        /// The minimum capacity for initial allocation and growth.
        @usableFromInline
        package let _minimumCapacity: Index.Count

        /// The growth policy used when the buffer needs to expand.
        @usableFromInline
        package let _growthPolicy: Buffer<Element>.Growth.Policy

        /// Creates a growable ring buffer with default minimum capacity (8) and doubling growth.
        ///
        /// Storage is not allocated until the first element is pushed.
        @inlinable
        public init() {
            self._storage = nil
            self._minimumCapacity = Index.Count(UInt(8))
            self._growthPolicy = .doubling
        }

        /// Creates a growable ring buffer with the specified minimum capacity and growth policy.
        ///
        /// Storage is not allocated until the first element is pushed.
        ///
        /// - Parameters:
        ///   - minimumCapacity: Minimum capacity for allocation. Defaults to 8.
        ///   - growthPolicy: Policy for computing new capacity on growth. Defaults to doubling.
        @inlinable
        public init(
            minimumCapacity: Index.Count = Index.Count(UInt(8)),
            growthPolicy: Buffer<Element>.Growth.Policy = .doubling
        ) {
            let minCap: Index.Count = minimumCapacity > .zero ? minimumCapacity : .one
            self._storage = nil
            self._minimumCapacity = minCap
            self._growthPolicy = growthPolicy
        }

        // No deinit needed - _Storage class handles cleanup via ARC

        // MARK: - Header

        /// Header for ring buffer storage.
        ///
        /// Tracks head (dequeue position), tail (enqueue position), and count.
        /// Used by Queue and Deque where elements wrap around the capacity boundary.
        ///
        /// ## Invariants
        ///
        /// - `count` reflects number of valid elements
        /// - Elements occupy physical positions from `head` to `(head + count - 1) % capacity`
        /// - `tail == (head + count) % capacity` when buffer is not full
        /// - `head == tail` when buffer is empty OR full (disambiguated by count)
        public struct Header: Sendable {
            /// Physical position of next element to dequeue.
            public var head: Index

            /// Physical position where next element will be enqueued.
            public var tail: Index

            /// Number of valid elements in the buffer.
            public var count: Index.Count

            /// Creates an empty ring buffer header.
            @inlinable
            public init() {
                self.head = .zero
                self.tail = .zero
                self.count = .zero
            }

            /// Creates a ring buffer header with specified values.
            ///
            /// - Parameters:
            ///   - head: Physical position of front element.
            ///   - tail: Physical position for next insertion.
            ///   - count: Number of elements.
            @inlinable
            public init(head: Index, tail: Index, count: Index.Count) {
                self.head = head
                self.tail = tail
                self.count = count
            }

            /// Whether the buffer is empty.
            @inlinable
            public var isEmpty: Bool {
                count == .zero
            }

            // MARK: - Header.Cyclic

            /// Cyclic-indexed header for compile-time capacity ring buffers.
            ///
            /// Uses `Buffer.Index.Cyclic<capacity>` for head and tail tracking,
            /// providing automatic wrapping arithmetic. This eliminates manual
            /// capacity parameters and makes invalid indices unrepresentable.
            ///
            /// ## Purpose
            ///
            /// Designed for use with `Storage.Static<Element, capacity>` to create
            /// fully static ring buffers with no runtime capacity plumbing. The cyclic
            /// index arithmetic is baked into the type, enabling:
            ///
            /// - Zero-allocation ring buffers (storage is inline)
            /// - Compile-time capacity enforcement
            /// - Eliminated runtime capacity parameters in all operations
            ///
            /// ## Example
            ///
            /// ```swift
            /// struct StaticRingBuffer<Element, let capacity: Int> {
            ///     var storage: Storage.Static<Element, capacity>
            ///     var header: Buffer.Ring.Header.Cyclic<capacity>
            /// }
            /// ```
            ///
            /// ## Relationship to Storage.Static
            ///
            /// While `Header` is used with dynamically-sized storage
            /// (`UnsafeMutablePointer<Element>`), `Header.Cyclic<capacity>` is the
            /// compile-time counterpart designed for `Storage.Static<Element, capacity>`.
            /// Together they enable fully static ring buffer implementations.
            public struct Cyclic<let capacity: Int>: Sendable {
                /// Physical position of the first element (next dequeue).
                public var head: Buffer.Index.Cyclic<capacity>

                /// Physical position for the next element (next enqueue).
                public var tail: Buffer.Index.Cyclic<capacity>

                /// Number of valid elements in the buffer.
                public var count: Buffer.Index.Count

                /// Creates an empty ring buffer header.
                @inlinable
                public init() {
                    self.head = .init(__unchecked: 0)
                    self.tail = .init(__unchecked: 0)
                    self.count = .zero
                }

                /// Creates a ring buffer header with specified values.
                @inlinable
                public init(
                    head: Buffer.Index.Cyclic<capacity>,
                    tail: Buffer.Index.Cyclic<capacity>,
                    count: Buffer.Index.Count
                ) {
                    self.head = head
                    self.tail = tail
                    self.count = count
                }

                /// Whether the buffer is empty.
                @inlinable
                public var isEmpty: Bool { count == .zero }

                /// Whether the buffer is full.
                @inlinable
                public var isFull: Bool { Int(bitPattern: count) == capacity }

                /// Converts the head position to a linear index.
                @inlinable
                public var headIndex: Buffer.Index {
                    Buffer.Index(Ordinal(head.rawValue.position.rawValue))
                }

                /// Converts the tail position to a linear index.
                @inlinable
                public var tailIndex: Buffer.Index {
                    Buffer.Index(Ordinal(tail.rawValue.position.rawValue))
                }
            }
        }

        // MARK: - Ring.Static (Bounded Circular Buffer)

        /// Bounded-capacity circular buffer for ~Copyable elements.
        ///
        /// A FIFO ring buffer with bounded capacity. Push operations fail when full.
        /// Uses move semantics for elements, supporting non-copyable types.
        ///
        /// ## Design
        ///
        /// - Backing storage: `UnsafeMutablePointer<Element>`
        /// - Slot tracking: `Buffer.Ring.Header` for head/tail/count
        /// - Bounded capacity: push returns rejected element when full (never grows)
        /// - FIFO ordering
        ///
        /// ## Thread Safety
        ///
        /// Not thread-safe. External synchronization required for concurrent access.
        @safe
        public struct Static: ~Swift.Copyable {
            @usableFromInline
            package var _storage: UnsafeMutablePointer<Element>

            @usableFromInline
            package var _header: Header

            /// The fixed capacity of the buffer.
            public let capacity: Buffer.Index.Count

            /// Creates a fixed-capacity ring buffer.
            ///
            /// - Parameter capacity: The maximum number of elements. Must be at least 1.
            @inlinable
            public init(capacity: Buffer.Index.Count) {
                precondition(capacity > .zero, "Capacity must be at least 1")
                self.capacity = capacity
                let base = UnsafeMutablePointer<Element>.allocate(capacity: Int(bitPattern: capacity))
                unsafe self._storage = UnsafeMutablePointer<Element>(base)
                self._header = Header()
            }

            deinit {
                Buffer.Ring.deinitialize(
                    _storage,
                    head: _header.head,
                    count: _header.count,
                    capacity: capacity
                )
                unsafe _storage.deallocate()
            }
        }
    }

    // MARK: - Slots (Namespace)

    /// Namespace for slot-based storage types.
    ///
    /// Provides fixed-capacity, index-addressable storage for ~Copyable elements
    /// with explicit initialization state tracking.
    public enum Slots {
        // MARK: - Slots.Static (Bounded Slot Store)

        /// Bounded-capacity, index-addressable slot store for ~Copyable elements.
        ///
        /// A slot store provides O(1) indexed insertion and removal with explicit
        /// initialization state tracking. Unlike arrays, slots can be individually
        /// occupied or empty, enabling immediate capacity reclamation on removal.
        ///
        /// ## Design
        ///
        /// - Backing storage: `UnsafeMutablePointer<Element>` (typed pointer)
        /// - Occupancy tracking: Word-backed bitset (~1 bit per slot)
        /// - Bounded capacity: known at init, never grows
        /// - Index-based access: O(1) put/take by typed index
        ///
        /// ## Thread Safety
        ///
        /// Not thread-safe. External synchronization required for concurrent access.
        @safe
        public struct Static: ~Copyable {
            @usableFromInline
            package var _storage: UnsafeMutablePointer<Element>

            @usableFromInline
            package var _occupied: Bitset

            @usableFromInline
            package var _count: Buffer.Index.Count

            /// The fixed capacity of the slot store.
            public let capacity: Buffer.Index.Count

            /// Creates a fixed-capacity slot store.
            ///
            /// All slots are initially empty (unoccupied).
            ///
            /// - Parameter capacity: The maximum number of elements. Must be at least 1.
            @inlinable
            public init(capacity: Index.Count) {
                precondition(capacity > .zero, "Capacity must be at least 1")
                self.capacity = capacity
                let capacityInt = Int(bitPattern: capacity)
                unsafe self._storage = UnsafeMutablePointer<Element>(
                    .allocate(capacity: capacityInt)
                )
                self._occupied = Bitset(capacity: capacityInt)
                self._count = .zero
            }

            deinit {
                let capacityInt = Int(bitPattern: capacity)
                for i in 0..<capacityInt {
                    if _occupied[i] {
                        unsafe (_storage + i).deinitialize(count: 1)
                    }
                }
                unsafe _storage.deallocate()
            }

            // MARK: - Slots.Static.Indexed

            /// A wrapper providing phantom-typed index access to bounded slot storage.
            ///
            /// `Indexed<Tag>` wraps a `Buffer.Slots.Static` and provides
            /// `put`/`take` access via `Index<Tag>` instead of `Buffer.Index`, enabling
            /// type-safe indexing where the phantom type differs from the element type.
            public struct Indexed<Tag: ~Copyable>: ~Copyable {
                @usableFromInline
                package var _storage: Buffer.Slots.Static

                /// Creates an indexed wrapper around the given storage.
                ///
                /// - Parameter storage: The slot storage to wrap.
                @inlinable
                public init(_ storage: consuming Buffer.Slots.Static) {
                    self._storage = storage
                }
            }
        }
    }

    // MARK: - Growth (Namespace)

    /// Namespace for growth policy types.
    public enum Growth {
        /// Policy for computing new capacity when a buffer needs to grow.
        ///
        /// Growth policies are value types that can be customized per-buffer
        /// or shared across multiple buffers.
        ///
        /// ## Built-in Policies
        ///
        /// - ``doubling``: Classic 2x growth (good general-purpose choice)
        /// - ``factor(_:)``: Custom multiplier (e.g., 1.5x for memory-constrained)
        /// - ``exact``: No over-allocation (minimizes memory, maximizes reallocations)
        public struct Policy: Sendable {
            @usableFromInline
            internal let _compute: @Sendable (Int, Int) -> Int

            /// Creates a growth policy with a custom computation function.
            ///
            /// - Parameter compute: A function that takes (currentCapacity, requiredCapacity)
            ///   and returns the new capacity. Must return a value >= requiredCapacity.
            @inlinable
            public init(_ compute: @escaping @Sendable (_ current: Int, _ required: Int) -> Int) {
                self._compute = compute
            }

            /// Computes the next capacity given current and required capacities.
            ///
            /// - Parameters:
            ///   - current: The current buffer capacity.
            ///   - required: The minimum capacity needed.
            /// - Returns: The new capacity (always >= required).
            @inlinable
            public func nextCapacity(current: Int, required: Int) -> Int {
                let result = _compute(current, required)
                return max(result, required)
            }
        }
    }
}

// MARK: - Sendable

extension Buffer.Ring: @unchecked Sendable where Element: Sendable {}
extension Buffer.Ring.Static: @unchecked Sendable where Element: Sendable {}
extension Buffer.Slots.Static: @unchecked Sendable where Element: Sendable {}
extension Buffer.Slots.Static.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}

// MARK: - Conditional Copyable

/// `Buffer.Ring` is `Copyable` when its elements are `Copyable`.
///
/// Copies share storage until mutation (copy-on-write). Use `_makeUnique()`
/// before mutating to ensure independent storage.
extension Buffer.Ring: Copyable where Element: Copyable {}
