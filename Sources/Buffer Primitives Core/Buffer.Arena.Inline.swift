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

        @usableFromInline
        package var header: Header

        @usableFromInline
        package var _meta: InlineArray<inlineCapacity, Meta>

        @usableFromInline
        package var _elements: _Elements

        @inlinable
        package init(
            header: Header,
            _meta: InlineArray<inlineCapacity, Meta>,
            _elements: consuming _Elements
        ) {
            self.header = header
            self._meta = _meta
            self._elements = _elements
        }

        /// Errors that can occur during inline arena buffer operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// A `Position` handle refers to a freed or never-allocated slot.
            case invalidPosition
            /// The number of elements exceeds the buffer's capacity.
            case capacityExceeded
        }

        deinit {
            let hw = Int(bitPattern: header.highWater)
            let stride = MemoryLayout<Element>.stride
            for i in 0..<hw {
                if _meta[i].isOccupied {
                    unsafe withUnsafePointer(to: _elements) { (ptr: UnsafePointer<_Elements>) -> Void in
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
extension Buffer.Arena.Inline: Sendable where Element: Sendable {}
