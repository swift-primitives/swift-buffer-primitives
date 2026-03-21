import Index_Primitives

extension Buffer where Element: ~Copyable {
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
        // MARK: - Header

        /// Pure cursor state for a dynamic-capacity ring buffer.
        ///
        /// Copyable and Sendable — this is just a few integers.
        ///
        /// Blueprint: `Experiments/ring-buffer-architecture-validation/Sources/main.swift:48-101`
        public struct Header: Copyable, Sendable {
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

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        // WORKAROUND: Inline defined in Ring's struct body (not via extension)
        // to avoid the LLVM verifier crash triggered by the extension-file
        // pattern for @_rawLayout + deinit types under -O.
        // WHEN TO REMOVE: When swiftlang/swift fixes the LLVM verifier crash
        //      for @_rawLayout + deinit under -O.
        // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md

        /// A fixed-capacity ring buffer backed by inline (stack-allocated) storage.
        ///
        /// Uses `Storage<Element>.Inline<capacity>` for stack-based allocation
        /// and the runtime `Header` for ring state tracking.
        ///
        /// Element cleanup is handled by deinit, which iterates the
        /// per-slot bitvector in `Storage.Inline` to deinitialize all
        /// initialized elements.
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

            // WORKAROUND: deinit commented out due to swiftlang/swift#86652.
            // Elements LEAK if a non-empty Ring.Inline is dropped without
            // draining. Affects class-typed and ~Copyable elements only.
            //
            // Combined @_rawLayout approach works for `internal` types but
            // crashes for `public` types. Blocked until compiler bug is fixed.
            // TRACKING: Research/rawlayout-release-crash-investigation.md
            //
            // deinit {
            //     unsafe storage.deinitialize()
            // }

            /// Errors that can occur during inline ring buffer operations.
            public enum Error: Swift.Error, Sendable, Equatable {
                /// The number of elements exceeds the buffer's capacity.
                case capacityExceeded
            }
        }

        // MARK: - Ring Fields

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Heap

        @inlinable
        package init(header: Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }

    }
}

extension Buffer.Ring: Copyable where Element: Copyable {}
extension Buffer.Ring: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Ring.Inline: Copyable where Element: Copyable {}
// extension Buffer.Ring.Inline: Swift.Sequence where Element: Copyable {}
extension Buffer.Ring.Inline: Sendable where Element: Sendable {}
