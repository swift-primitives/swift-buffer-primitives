public import Buffer_Primitives_Core

// MARK: - forEach.occupied for Arena

extension Property.View where Base: ~Copyable {

    /// Visits each occupied slot in the arena.
    @inlinable
    public func occupied<Element>(
        _ body: (Index<Element>) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Arena {
        let meta = unsafe base.pointee.storage.metaBase
        Buffer<Element>.Arena.forEach(
            occupied: unsafe base.pointee.header,
            meta: meta,
            body
        )
    }
}

// MARK: - forEach.occupied for Arena.Bounded

extension Property.View where Base: ~Copyable {

    /// Visits each occupied slot in the bounded arena.
    @inlinable
    public func occupied<Element>(
        _ body: (Index<Element>) -> Void
    ) where Tag == Sequence.ForEach, Base == Buffer<Element>.Arena.Bounded {
        let meta = unsafe base.pointee.storage.metaBase
        Buffer<Element>.Arena.forEach(
            occupied: unsafe base.pointee.header,
            meta: meta,
            body
        )
    }
}
