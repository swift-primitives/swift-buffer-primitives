public import Buffer_Primitives_Core

// MARK: - forEach.occupied for Slab

extension Property.View.Read where Base: ~Copyable {

    /// Visits each occupied slot in the slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Slab {
        unsafe base.pointee.header.bitmap.ones.forEach(body)
    }
}

// MARK: - forEach.occupied for Slab.Bounded

extension Property.View.Read where Base: ~Copyable {

    /// Visits each occupied slot in the bounded slab.
    ///
    /// Uses Wegner/Kernighan bit iteration — O(count) rather than O(capacity).
    @inlinable
    public func occupied<Element>(
        _ body: (Bit.Index) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Slab.Bounded {
        unsafe base.pointee.header.bitmap.ones.forEach(body)
    }
}
