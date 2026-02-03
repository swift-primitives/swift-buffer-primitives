// MARK: - Static Operations for Copyable Elements on Storage.Heap

extension Buffer.Ring {

    /// Copies all elements from source to destination storage in logical order.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`
    /// in FIFO order (linearized).
    @inlinable
    public static func linearize<Element: Copyable>(
        header: Header,
        source: Storage.Heap<Element>,
        to destination: Storage.Heap<Element>
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            source.copy(range: range, to: destination)
        case .two(let first, let second):
            source.copy(range: first, to: destination)
            let offset = first.count.rawValue.rawValue
            let secondCount = second.count.rawValue.rawValue
            for i: UInt in 0 ..< secondCount {
                let srcIdx = Index<Storage>(Ordinal(second.lowerBound.rawValue.rawValue &+ i))
                let dstIdx = Index<Storage>(Ordinal(offset &+ i))
                let value: Element = unsafe source.pointer(at: srcIdx).pointee
                destination.initialize(to: value, at: dstIdx)
            }
        }
    }

    /// Copies all ring elements to a new storage, linearized to slots `0 ..< count`.
    @inlinable
    public static func copy<Element: Copyable>(
        header: Header,
        source: Storage.Heap<Element>,
        to destination: Storage.Heap<Element>
    ) {
        linearize(header: header, source: source, to: destination)
    }
}
