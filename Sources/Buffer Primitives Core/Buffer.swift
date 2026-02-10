import Vector_Primitives
import Index_Primitives

/// Namespace for buffer primitives.
///
/// Buffer provides four disciplines for managing elements in storage:
/// - ``Buffer/Linear``: Contiguous front-to-back storage
/// - ``Buffer/Ring``: Circular FIFO/LIFO storage with wrap-around
/// - ``Buffer/Slab``: Sparse index-addressable slot storage
/// - ``Buffer/Slots``: Metadata-parametric random-access slots
///
/// Each discipline follows a three-layer architecture:
/// 1. **Header** — Pure cursor/bookkeeping state (Layer 1)
/// 2. **Static Operations** — Expert-level functions on `Storage.Heap` (Layer 2)
/// 3. **Composed Types** — User-facing types that delegate to static ops (Layer 3)
///
/// - Note: `Ring`, `Linear`, `Slab`, `Slots`, and all their nested types are declared
///   inside the enum body (not in extensions) due to Swift compiler constraints
///   on nested types within `~Copyable` generic types.
public enum Buffer<Element: ~Copyable> {

    // MARK: - Ring

    /// A growable ring buffer backed by heap storage.
    ///
    /// Provides double-ended push/pop operations with automatic capacity growth.
    /// Delegates all element manipulation to `Buffer.Ring` static operations
    /// defined in the `Buffer Ring Primitives` module.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Ring: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Heap

        @inlinable
        package init(header: Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }

        // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity ring buffer backed by heap storage.
        ///
        /// Push operations on a full buffer return the rejected element
        /// rather than growing.
        ///
        /// `storage.initialization` is kept in sync with header state,
        /// so `Storage.Heap`'s own deinit handles cleanup automatically.
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage<Element>.Heap

            @inlinable
            package init(header: Header, storage: Storage<Element>.Heap) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during bounded ring buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
        /// and the runtime `Header` for ring state tracking.
        ///
        /// Unlike heap-backed `Bounded`, this type does not automatically
        /// deinitialize on drop when Element is Copyable. When Element is
        /// ~Copyable, deinit handles cleanup.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage<Element>.Inline<capacity>

            @inlinable
            package init(header: Header, storage: consuming Storage<Element>.Inline<capacity>) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during inline ring buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Small (Inline + Heap Spill)

        /// A ring buffer that starts with inline storage and spills to heap
        /// when capacity is exceeded.
        ///
        /// In inline mode, uses `Storage<Element>.Inline<inlineCapacity>` with
        /// ring-buffer wrap-around. After spill, elements are linearized into
        /// a growable `Buffer<Element>.Ring`.
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @usableFromInline
            package var _inlineBuffer: Inline<inlineCapacity>

            @usableFromInline
            package var _heapBuffer: Buffer<Element>.Ring?

            @inlinable
            package init(
                _inlineBuffer: consuming Inline<inlineCapacity>,
                _heapBuffer: consuming Buffer<Element>.Ring?
            ) {
                self._inlineBuffer = _inlineBuffer
                self._heapBuffer = _heapBuffer
            }
        }

        // MARK: - Header

        /// Pure cursor state for a dynamic-capacity ring buffer.
        ///
        /// Copyable and Sendable — this is just a few integers.
        ///
        /// Blueprint: `Experiments/ring-buffer-architecture-validation/Sources/main.swift:48-101`
        public struct Header: Copyable, Sendable, Hashable {
            /// Slot index of the first element.
            public var head: Index<Element>

            /// Number of initialized elements.
            public var count: Index<Element>.Count

            /// Total slot capacity.
            public let capacity: Index<Element>.Count

            /// Creates a header with the given capacity and zero elements.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.head = .zero
                self.count = .zero
                self.capacity = capacity
            }

            // MARK: - Header.Cyclic

            /// Compile-time capacity ring header using modular arithmetic.
            ///
            /// Uses `Index<Element>.Cyclic<capacity>` for the head position, providing
            /// automatic wrap-around via the cyclic group Z/capacityZ. The capacity
            /// is encoded in the type — no stored capacity field needed.
            public struct Cyclic<let capacity: Int>: Copyable, Sendable {
                /// Slot index of the first element (modular, wraps at capacity).
                public var head: Index<Element>.Cyclic<capacity>

                /// Number of initialized elements.
                public var count: Index<Element>.Count

                /// Creates a header with zero elements.
                @inlinable
                public init() {
                    self.head = Index<Element>.Cyclic<capacity>(__unchecked: Ordinal(0))
                    self.count = .zero
                }
            }
        }
    }

    // MARK: - Linear

    /// A growable linear buffer backed by heap storage.
    ///
    /// Provides append and consume operations with automatic capacity growth.
    /// Elements are stored contiguously at slots `0 ..< count`.
    ///
    /// `storage.initialization` is kept in sync with header state,
    /// so `Storage.Heap`'s own deinit handles cleanup automatically.
    public struct Linear: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Heap

        @inlinable
        package init(header: Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }

        // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity linear buffer backed by heap storage.
        ///
        /// `storage.initialization` is kept in sync with header state,
        /// so `Storage.Heap`'s own deinit handles cleanup automatically.
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage<Element>.Heap

            @inlinable
            package init(header: Header, storage: Storage<Element>.Heap) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during bounded linear buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity linear buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
        /// and the runtime `Header` for linear state tracking.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage<Element>.Inline<capacity>

            @inlinable
            package init(header: Header, storage: consuming Storage<Element>.Inline<capacity>) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during inline linear buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Small (Inline + Heap Spill)

        /// A linear buffer that starts with inline storage and spills to heap
        /// when capacity is exceeded.
        ///
        /// Elements are stored contiguously at slots `0 ..< count`.
        /// In inline mode, uses `Storage<Element>.Inline<inlineCapacity>`.
        /// After spill, uses `Storage<Element>.Heap` (growable).
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @usableFromInline
            package var _inlineBuffer: Inline<inlineCapacity>

            @usableFromInline
            package var _heapBuffer: Buffer<Element>.Linear?

            @inlinable
            package init(
                _inlineBuffer: consuming Inline<inlineCapacity>,
                _heapBuffer: consuming Buffer<Element>.Linear?
            ) {
                self._inlineBuffer = _inlineBuffer
                self._heapBuffer = _heapBuffer
            }
        }

        // MARK: - Header

        /// Pure cursor state for a linear (contiguous) buffer.
        ///
        /// Linear buffers store elements at slots `0 ..< count`. The header tracks
        /// the current element count and total capacity.
        ///
        /// Initialization is always `.one(idx(0) ..< idx(count))` — a single
        /// contiguous range starting at zero.
        public struct Header: Copyable, Sendable {
            /// Number of initialized elements.
            public var count: Index<Element>.Count

            /// Total slot capacity.
            public let capacity: Index<Element>.Count

            /// Creates a header with the given capacity and zero elements.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.count = .zero
                self.capacity = capacity
            }
        }
    }

    // MARK: - Slab

    /// A dynamic-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Slab: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Heap

        @inlinable
        package init(header: consuming Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }

        deinit {
            // Slab deinit is NOT automatic — bitmap drives cleanup.
            // Note: uses `for...in` instead of `forEach` to avoid a
            // MoveOnlyChecker crash (swift-frontend signal 11) — closures
            // capturing ~Copyable fields of `self` inside deinit trigger
            // CopiedLoadBorrowEliminationVisitor to segfault.
            for bitIndex in header.bitmap.ones {
                storage.deinitialize(at: bitIndex.retag())
            }
            storage.initialization = .empty
        }

        // MARK: - Bounded (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity slab buffer backed by heap storage.
        ///
        /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
        /// the bitmap is the source of truth. **deinit MUST explicitly iterate
        /// `header.bitmap.ones` and deinitialize each occupied slot.**
        public struct Bounded: ~Copyable {
            @usableFromInline
            package var header: Header

            @usableFromInline
            package var storage: Storage<Element>.Heap

            @inlinable
            package init(
                header: consuming Header,
                storage: Storage<Element>.Heap
            ) {
                self.header = header
                self.storage = storage
            }

            deinit {
                // Slab deinit is NOT automatic — bitmap drives cleanup.
                // Note: uses `for...in` instead of `forEach` to avoid a
                // MoveOnlyChecker crash (swift-frontend signal 11).
                for bitIndex in header.bitmap.ones {
                    storage.deinitialize(at: bitIndex.retag())
                }
                storage.initialization = .empty
            }

            /// Errors that can occur during bounded slab buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }

            // MARK: - Bounded.Indexed

            /// Phantom-typed wrapper providing `Index<Tag>` access to slab storage.
            ///
            /// Uses `Tagged.retag()` per H2 for zero-cost `Index<Tag>` <-> `Index<Element>` conversion.
            public struct Indexed<Tag: ~Copyable>: ~Copyable {
                @usableFromInline
                package var _base: Bounded

                @inlinable
                package init(_base: consuming Bounded) {
                    self._base = _base
                }
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        /// A fixed-capacity slab buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage<Element>.Inline<wordCount>` for stack-based allocation
        /// and `Header.Static<wordCount>` for the bitmap.
        ///
        /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
        /// stays `.empty`.
        public struct Inline<let wordCount: Int>: ~Copyable {
            @usableFromInline
            package var header: Header.Static<wordCount>

            @usableFromInline
            package var storage: Storage<Element>.Inline<wordCount>

            @inlinable
            package init(
                header: Header.Static<wordCount>,
                storage: consuming Storage<Element>.Inline<wordCount>
            ) {
                self.header = header
                self.storage = storage
            }

            /// Errors that can occur during inline slab buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Header

        /// Cursor state for a slab (sparse slot) buffer.
        /// 
        /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
        /// are occupied. `storage.initialization` stays `.empty` — the bitmap
        /// drives all cleanup.
        ///
        /// ~Copyable because `Bit.Vector` is ~Copyable.
        ///
        /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
        public struct Header: ~Copyable {
            /// Bitmap tracking which slots are occupied.
            public var bitmap: Bit.Vector

            /// Creates a header with the given slot capacity, all vacant.
            @inlinable
            public init(capacity: Bit.Index.Count) {
                self.bitmap = Bit.Vector(capacity: capacity)
            }

            // MARK: - Header.Static

            /// Compile-time word count slab header using `Bit.Vector.Static`.
            ///
            /// Unlike `Buffer.Slab.Header` which uses `Bit.Vector` (~Copyable),
            /// this type uses `Bit.Vector.Static<wordCount>` which IS Copyable.
            /// This means types using this header CAN be Copyable when their
            /// elements are Copyable.
            public struct Static<let wordCount: Int>: Copyable, Sendable {
                /// Bitmap tracking which slots are occupied.
                public var bitmap: Bit.Vector.Static<wordCount>

                /// Creates a header with all slots vacant.
                @inlinable
                public init() {
                    self.bitmap = .init()
                }
            }
        }
    }

    // MARK: - Slots

    /// A fixed-capacity slots buffer backed by split storage.
    ///
    /// Provides metadata-parametric random-access slots with a single
    /// heap allocation containing both metadata and element arrays.
    ///
    /// ## Metadata-Driven Storage
    ///
    /// Unlike Linear/Ring (range-tracked) and Slab (bitmap-tracked),
    /// Slots performs **no element lifecycle management**. The consumer
    /// determines slot occupancy through the metadata values — for example,
    /// a Swiss-table hash map uses `0x80` for empty and `h2` hash bits
    /// for occupied.
    ///
    /// ## Consumer-Managed Element Lifecycle
    ///
    /// `Buffer.Slots` has no deinit for elements. Any consumer that
    /// initializes element slots must deinitialize them before releasing
    /// the buffer, typically via ``deinitialize(where:)``.
    /// This is a capability boundary — the same contract as
    /// `Storage.Split`.
    ///
    /// ## No Growth
    ///
    /// Fixed-capacity. Consumers requiring growth must allocate a new
    /// `Buffer.Slots` and re-insert elements (e.g., hash table rehash).
    public struct Slots<Metadata: BitwiseCopyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Split<Metadata>

        @inlinable
        package init(header: Header, storage: Storage<Element>.Split<Metadata>) {
            self.header = header
            self.storage = storage
        }

        // MARK: - Header

        /// Pure state for a slots buffer.
        ///
        /// The header is trivial — just capacity. Unlike Linear (count),
        /// Ring (head + count), or Slab (bitmap), Slots has no mutable
        /// cursor state. All state lives in the metadata array.
        public struct Header: Copyable, Sendable, Hashable {
            /// Total slot capacity.
            public let capacity: Index<Element>.Count

            /// Creates a header with the specified capacity.
            @inlinable
            public init(capacity: Index<Element>.Count) {
                self.capacity = capacity
            }
        }
    }
}

// MARK: - Conditional Conformances (Ring)

extension Buffer.Ring: Copyable where Element: Copyable {}
extension Buffer.Ring: @unchecked Sendable where Element: Sendable {}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: @unchecked Sendable where Element: Sendable {}

// Cannot conform to Copyable: Storage.Inline uses @_rawLayout which is
// unconditionally ~Copyable (INV-INLINE-004a). @_rawLayout is required
// because InlineArray has no uninitialized API and requires Copyable for
// init(repeating:), but Storage.Inline must support ~Copyable elements.
// If Swift adds InlineArray.init(unsafeUninitializedCapacity:), Storage.Inline
// could migrate and this conformance can be restored.
// extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}

// Cannot conform to Copyable: contains Inline which uses @_rawLayout (INV-INLINE-004a).
// extension Buffer.Ring.Small: Copyable where Element: Copyable {}
extension Buffer.Ring.Small: Sendable where Element: Sendable {}

// MARK: - Conditional Conformances (Linear)

extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear: @unchecked Sendable where Element: Sendable {}

extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
extension Buffer.Linear.Bounded: @unchecked Sendable where Element: Sendable {}

// Cannot conform to Copyable: Storage.Inline uses @_rawLayout which is
// unconditionally ~Copyable (INV-INLINE-004a). @_rawLayout is required
// because InlineArray has no uninitialized API and requires Copyable for
// init(repeating:), but Storage.Inline must support ~Copyable elements.
// If Swift adds InlineArray.init(unsafeUninitializedCapacity:), Storage.Inline
// could migrate and this conformance can be restored.
// extension Buffer.Linear.Inline: Copyable where Element: Copyable {}
// extension Buffer.Linear.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Linear.Inline: Sendable where Element: Sendable {}

// Cannot conform to Copyable: contains Inline which uses @_rawLayout (INV-INLINE-004a).
// extension Buffer.Linear.Small: Copyable where Element: Copyable {}
extension Buffer.Linear.Small: Sendable where Element: Sendable {}

// MARK: - Conditional Conformances (Slab)

extension Buffer.Slab: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}

// Cannot conform to Copyable: Storage.Inline uses @_rawLayout which is
// unconditionally ~Copyable (INV-INLINE-004a). @_rawLayout is required
// because InlineArray has no uninitialized API and requires Copyable for
// init(repeating:), but Storage.Inline must support ~Copyable elements.
// If Swift adds InlineArray.init(unsafeUninitializedCapacity:), Storage.Inline
// could migrate and this conformance can be restored.
// extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
// extension Buffer.Slab.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}

// MARK: - Conditional Conformances (Slots)

extension Buffer.Slots: Copyable where Element: Copyable {}
extension Buffer.Slots: @unchecked Sendable where Element: Sendable {}
