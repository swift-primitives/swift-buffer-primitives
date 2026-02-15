// MARK: - Checkpoint for Ring

extension Buffer.Ring where Element: ~Copyable {

    /// Captures the current cursor state as a checkpoint.
    @inlinable
    public var checkpoint: Checkpoint {
        Checkpoint(head: header.head, count: header.count)
    }

    /// Restores cursor state from a previously captured checkpoint.
    ///
    /// Updates head and count, then synchronizes `storage.initialization`.
    @inlinable
    public mutating func restore(to checkpoint: Checkpoint) {
        header.head = checkpoint.head
        header.count = checkpoint.count
        storage.initialization = header.initialization
    }
}

// MARK: - Checkpoint for Ring.Bounded

extension Buffer.Ring.Bounded where Element: ~Copyable {

    /// Captures the current cursor state as a checkpoint.
    @inlinable
    public var checkpoint: Buffer.Ring.Checkpoint {
        Buffer.Ring.Checkpoint(head: header.head, count: header.count)
    }

    /// Restores cursor state from a previously captured checkpoint.
    ///
    /// Updates head and count, then synchronizes `storage.initialization`.
    @inlinable
    public mutating func restore(to checkpoint: Buffer.Ring.Checkpoint) {
        header.head = checkpoint.head
        header.count = checkpoint.count
        storage.initialization = header.initialization
    }
}

// MARK: - Checkpoint for Ring.Inline

extension Buffer.Ring.Inline where Element: ~Copyable {

    /// Captures the current cursor state as a checkpoint.
    @inlinable
    public var checkpoint: Buffer.Ring.Checkpoint {
        Buffer.Ring.Checkpoint(head: header.head, count: header.count)
    }

    /// Restores cursor state from a previously captured checkpoint.
    ///
    /// Updates head and count. Inline storage does not track initialization.
    @inlinable
    public mutating func restore(to checkpoint: Buffer.Ring.Checkpoint) {
        header.head = checkpoint.head
        header.count = checkpoint.count
    }
}

// MARK: - Checkpoint for Ring.Small

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Captures the current cursor state as a checkpoint.
    @inlinable
    public var checkpoint: Checkpoint {
        switch _storage {
        case .heap(let heap):
            return Checkpoint(head: heap.header.head, count: heap.header.count, wasOnHeap: true)
        case .inline(let buf):
            return Checkpoint(head: buf.header.head, count: buf.header.count, wasOnHeap: false)
        }
    }

    /// Restores cursor state from a previously captured checkpoint.
    ///
    /// Routes to the appropriate storage based on the current mode.
    @inlinable
    public mutating func restore(to checkpoint: Checkpoint) {
        switch _storage {
        case .heap(var buf):
            buf.header.head = checkpoint.head
            buf.header.count = checkpoint.count
            buf.storage.initialization = buf.header.initialization
            self = Self(_storage: .heap(consume buf))
        case .inline(var buf):
            buf.header.head = checkpoint.head
            buf.header.count = checkpoint.count
            self = Self(_storage: .inline(consume buf))
        }
    }
}
