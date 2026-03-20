import Index_Primitives

extension Buffer.Ring where Element: ~Copyable {
    // MARK: - Small (Inline + Heap Spill)

    /// A ring buffer that starts with inline storage and spills to heap
    /// when capacity is exceeded.
    ///
    /// In inline mode, uses `Storage<Element>.Inline<inlineCapacity>` with
    /// ring-buffer wrap-around. After spill, elements are linearized into
    /// a growable `Buffer<Element>.Ring`.
    @frozen
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        // WORKAROUND: Enum storage instead of two-field struct
        // WHY: ~Copyable structs with both @_rawLayout fields (Storage.Inline)
        //      and ManagedBuffer class references (Storage.Heap) trigger LLVM
        //      verifier crash in release builds ("Instruction does not dominate
        //      all uses!"). Enum ensures only one variant is destroyed at a time.
        // WHEN TO REMOVE: When swiftlang/swift fixes the implicit destructor
        //      codegen for mixed @_rawLayout + class stored properties
        // TRACKING: swiftlang/swift LLVM verifier crash
        @frozen @usableFromInline
        package enum _Representation: ~Copyable {
            case inline(Buffer<Element>.Ring.Inline<inlineCapacity>)
            case heap(Buffer<Element>.Ring)
        }

        @usableFromInline
        package var _storage: _Representation

        @inlinable
        package init(_storage: consuming _Representation) {
            self._storage = _storage
        }

        /// A snapshot of small ring buffer cursor state for save/restore.
        ///
        /// Tracks whether the buffer was heap-backed at checkpoint time
        /// so restore can route to the correct storage.
        ///
        /// Ordering and equality semantics match `Buffer.Ring.Checkpoint`.
        public struct Checkpoint: Copyable, Sendable, Comparable {
            @usableFromInline
            package let head: Index<Element>

            @usableFromInline
            package let count: Index<Element>.Count

            @usableFromInline
            package let wasOnHeap: Bool

            @inlinable
            package init(head: Index<Element>, count: Index<Element>.Count, wasOnHeap: Bool) {
                self.head = head
                self.count = count
                self.wasOnHeap = wasOnHeap
            }

            @inlinable
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.count == rhs.count
            }

            @inlinable
            public static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.count > rhs.count
            }
        }
    }
}

// Copyable suppressed per INV-INLINE-004a (contains Inline).
// extension Buffer.Ring.Small: Copyable where Element: Copyable {}
extension Buffer.Ring.Small._Representation: @unchecked Sendable where Element: Sendable {}
extension Buffer.Ring.Small: Sendable where Element: Sendable {}
