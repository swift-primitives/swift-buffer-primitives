// MARK: - ~Copyable forEach for Ring

extension Buffer.Ring where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in FIFO order.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        header.initialization.forEach { range in
            var slot = range.lowerBound
            while slot < range.upperBound {
                body(unsafe storage.pointer(at: slot).pointee)
                slot += .one
            }
        }
    }
}

// MARK: - ~Copyable forEach for Ring.Bounded

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in FIFO order.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        header.initialization.forEach { range in
            var slot = range.lowerBound
            while slot < range.upperBound {
                body(unsafe storage.pointer(at: slot).pointee)
                slot += .one
            }
        }
    }
}

// MARK: - ~Copyable forEach for Ring.Inline

extension Buffer.Ring.Inline where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in FIFO order.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        header.initialization.forEach { range in
            var slot = range.lowerBound
            while slot < range.upperBound {
                let bounded = Index<Element>.Bounded<capacity>(slot)!
                let ptr: UnsafePointer<Element> = unsafe storage.pointer(at: bounded)
                body(unsafe ptr.pointee)
                slot += .one
            }
        }
    }
}

// MARK: - ~Copyable forEach for Ring.Small

extension Buffer.Ring.Small where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in FIFO order.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        switch _storage {
        case .heap(let heap): heap.forEach(body)
        case .inline(let buf): buf.forEach(body)
        }
    }
}
