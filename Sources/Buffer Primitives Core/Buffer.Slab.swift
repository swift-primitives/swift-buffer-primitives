extension Buffer {
    /// A dynamic-capacity slab buffer backed by heap storage.
    ///
    /// Unlike Ring and Linear, Slab's `storage.initialization` stays `.empty` —
    /// the bitmap is the source of truth. **deinit MUST explicitly iterate
    /// `header.bitmap.ones` and deinitialize each occupied slot.**
    ///
    /// - Note: `Bounded`, `Inline`, `Header`, and `Bounded.Indexed` are declared
    ///   inside the struct body (not in extensions) due to Swift compiler constraints
    ///   on nested types within `~Copyable` generic types.
    public struct Slab<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: Storage.Heap<Element>

        @inlinable
        package init(header: consuming Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            // Slab deinit is NOT automatic — bitmap drives cleanup.
            header.bitmap.ones.forEach { bitIndex in
                let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
                storage.deinitialize(at: storageIndex)
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
            package var storage: Storage.Heap<Element>

            @inlinable
            package init(header: consuming Header, storage: Storage.Heap<Element>) {
                self.header = header
                self.storage = storage
            }

            deinit {
                // Slab deinit is NOT automatic — bitmap drives cleanup.
                header.bitmap.ones.forEach { bitIndex in
                    let storageIndex = Index<Storage>(Ordinal(bitIndex.rawValue.rawValue))
                    storage.deinitialize(at: storageIndex)
                }
                storage.initialization = .empty
            }

            // MARK: - Bounded.Indexed

            /// Phantom-typed wrapper providing `Index<Tag>` access to slab storage.
            ///
            /// Uses `Tagged.retag()` per H2 for zero-cost `Index<Tag>` <-> `Index<Storage>` conversion.
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
        /// Uses `Storage.Inline<Element, wordCount>` for stack-based allocation
        /// and `Header.Static<wordCount>` for the bitmap.
        ///
        /// The bitmap drives cleanup — `Storage.Inline`'s initialization state
        /// stays `.empty`.
        public struct Inline<let wordCount: Int>: ~Copyable {
            @usableFromInline
            package var header: Header.Static<wordCount>

            @usableFromInline
            package var storage: Storage.Inline<Element, wordCount>

            @inlinable
            package init(header: Header.Static<wordCount>, storage: consuming Storage.Inline<Element, wordCount>) {
                self.header = header
                self.storage = storage
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

            /// The number of occupied slots.
            @inlinable
            public var occupancy: Bit.Index.Count {
                bitmap.popcount
            }

            /// Whether no slots are occupied.
            @inlinable
            public var isEmpty: Bool {
                bitmap.isEmpty
            }

            /// Whether all slots are occupied.
            @inlinable
            public var isFull: Bool {
                bitmap.isFull
            }

            /// Checks whether a specific slot is occupied.
            @inlinable
            public func isOccupied(at slot: Bit.Index) -> Bool {
                bitmap[slot]
            }

            /// Finds the first vacant slot by scanning the bitmap.
            ///
            /// Returns `nil` if all slots are full.
            @inlinable
            public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
                let maxRaw = max.rawValue.rawValue
                for i: UInt in 0 ..< maxRaw {
                    let idx = Bit.Index(Ordinal(i))
                    if !bitmap[idx] {
                        return idx
                    }
                }
                return nil
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

                /// The number of occupied slots.
                @inlinable
                public var occupancy: Bit.Index.Count {
                    bitmap.popcount
                }

                /// Whether no slots are occupied.
                @inlinable
                public var isEmpty: Bool {
                    bitmap.isEmpty
                }

                /// Whether all slots are occupied.
                @inlinable
                public var isFull: Bool {
                    bitmap.isFull
                }

                /// Checks whether a specific slot is occupied.
                @inlinable
                public func isOccupied(at slot: Bit.Index) -> Bool {
                    bitmap[slot]
                }

                /// Finds the first vacant slot by scanning the bitmap.
                ///
                /// Returns `nil` if all slots are full.
                @inlinable
                public func firstVacant(max: Bit.Index.Count) -> Bit.Index? {
                    let maxRaw = max.rawValue.rawValue
                    for i: UInt in 0 ..< maxRaw {
                        let idx = Bit.Index(Ordinal(i))
                        if !bitmap[idx] {
                            return idx
                        }
                    }
                    return nil
                }
            }
        }
    }
}

// MARK: - Conditional Conformances

extension Buffer.Slab: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded: @unchecked Sendable where Element: Sendable {}

extension Buffer.Slab.Bounded.Indexed: @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}

extension Buffer.Slab.Inline: Copyable where Element: Copyable {}
extension Buffer.Slab.Inline: Sendable where Element: Sendable {}
