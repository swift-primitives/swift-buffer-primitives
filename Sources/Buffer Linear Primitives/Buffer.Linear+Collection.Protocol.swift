public import Collection_Primitives

// MARK: - Collection.Protocol

extension Buffer.Linear: Collection.`Protocol` where Element: Copyable {
    @inlinable
    public var startIndex: Index_Primitives.Index<Element> { .zero }

    @inlinable
    public var endIndex: Index_Primitives.Index<Element> {
        header.count.map(Ordinal.init)
    }

    @inlinable
    public func index(after i: Index_Primitives.Index<Element>) -> Index_Primitives.Index<Element> {
        try! i + Index_Primitives.Index<Element>.Offset(1)
    }
}
