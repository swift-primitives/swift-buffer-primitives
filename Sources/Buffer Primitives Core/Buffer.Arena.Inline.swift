import Index_Primitives

extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

    /// A fixed-capacity arena buffer backed by inline (stack-allocated) storage.
    ///
    /// Provides the same token-based occupancy tracking and LIFO free-list
    /// as heap-backed `Arena` and `Bounded`, but stored entirely inline.
    /// Allocation throws `.capacityExceeded` when capacity is exhausted.
    ///
    /// Uses `InlineArray` for per-slot `Meta` (generation tokens + free-list
    /// links) and `@_rawLayout` for element storage.
    public struct Inline<let inlineCapacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: inlineCapacity)
        @usableFromInline
        package struct _Elements: ~Copyable, @unchecked Sendable {
            @usableFromInline package init() {}
        }

        // WORKAROUND: Enum wrapping for @_rawLayout storage to avoid LLVM verifier
        // crash in release builds. ~Copyable structs with @_rawLayout stored fields
        // + explicit deinit trigger "Instruction does not dominate all uses!".
        // See Buffer.Ring.Small for extended rationale.
        @usableFromInline
        package enum _ElementsRepr: ~Copyable, @unchecked Sendable {
            case active(_Elements)
        }

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var _meta: InlineArray<inlineCapacity, Meta>

        @usableFromInline
        package var _elements: _ElementsRepr

        @inlinable
        package init(
            header: Header,
            _meta: InlineArray<inlineCapacity, Meta>,
            _elements: consuming _Elements
        ) {
            self.header = header
            self._meta = _meta
            self._elements = .active(_elements)
        }

        /// Errors that can occur during inline arena buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// A `Position` handle refers to a freed or never-allocated slot.
            case invalidPosition
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }

        deinit {
            guard case .active(var elements) = _elements else { return }
            // WORKAROUND: Uses `for i in` instead of `.forEach` closure
            // WHY: Closures capturing ~Copyable fields of `self` inside deinit trigger
            //      CopiedLoadBorrowEliminationVisitor segfault (swift-frontend signal 11)
            // WHEN TO REMOVE: When MoveOnlyChecker deinit closure crash is fixed
            let hw = Int(bitPattern: header.highWater)
            let stride = MemoryLayout<Element>.stride
            for i in 0..<hw {
                if _meta[i].isOccupied {
                    // Use borrowing pointer + mutating cast: safe in deinit (we own the memory).
                    unsafe withUnsafePointer(to: elements) { (ptr: UnsafePointer<_Elements>) -> Void in
                        unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(ptr))
                            .advanced(by: i * stride)
                            .assumingMemoryBound(to: Element.self)
                            .deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Conditional Conformances (Arena.Inline)

// Copyable suppressed per INV-INLINE-004a.
// extension Buffer.Arena.Inline: Copyable where Element: Copyable {}
extension Buffer.Arena.Inline: Sendable where Element: Sendable {}
