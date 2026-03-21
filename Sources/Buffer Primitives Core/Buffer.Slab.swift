import Index_Primitives

extension Buffer where Element: ~Copyable {

    // MARK: - Slab

    /// A dynamic-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    public struct Slab: ~Copyable {
        // MARK: - Header

        /// Cursor state for a slab (sparse slot) buffer.
        ///
        /// Uses a `Bit.Vector` bitmap as the source of truth for which slots
        /// are occupied. `storage.initialization` stays `.empty` — the bitmap
        /// drives all cleanup.
        ///
        /// Copyable because `Bit.Vector.Bounded` (ContiguousArray-backed) is Copyable.
        ///
        /// Blueprint: `Experiments/initialization-consistency/Sources/main.swift:249-311`
        public struct Header {
            /// Bitmap tracking which slots are occupied.
            public var bitmap: Bit.Vector.Bounded

            /// Creates a header with the given slot capacity, all vacant.
            @inlinable
            public init(capacity: Bit.Index.Count) {
                self.bitmap = try! Bit.Vector.Bounded(capacity: capacity, count: capacity)
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

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

        // WORKAROUND: Inline defined in Slab's struct body (not via extension)
        // to avoid the LLVM verifier crash triggered by the extension-file
        // pattern for @_rawLayout + deinit types under -O.
        // WHEN TO REMOVE: When swiftlang/swift fixes the LLVM verifier crash
        //      for @_rawLayout + deinit under -O.
        // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md

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

            deinit {
                var slot: Bit.Index = .zero
                let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
                while slot < end {
                    if header.bitmap[slot] {
                        let elementSlot = Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!
                        unsafe storage.pointer(at: elementSlot).deinitialize(count: 1)
                    }
                    slot += .one
                }
            }
        }

        // MARK: - Slab Fields

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage<Element>.Slab

        @inlinable
        package init(header: Header, storage: Storage<Element>.Slab) {
            self.header = header
            self.storage = storage
        }

        // No deinit — Storage.Slab handles element cleanup via bitmap iteration
    }
}

extension Buffer.Slab: Copyable where Element: Copyable {}
extension Buffer.Slab: @unchecked Sendable where Element: Sendable {}

// Copyable suppressed per INV-INLINE-004a.
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
