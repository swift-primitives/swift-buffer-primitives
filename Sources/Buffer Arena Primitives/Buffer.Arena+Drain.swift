public import Buffer_Primitives_Core

// MARK: - Sequence.Drain.Protocol for Arena

extension Buffer.Arena: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let meta = unsafe storage.meta
        Buffer<Element>.Arena.forEach(occupied: header, meta: meta) { slot in
            let element = storage.move(at: slot)
            Buffer<Element>.Arena._releaseSlot(slot, header: &header, meta: meta)
            body(element)
        }
        storage.highWater = .zero
    }
}

// MARK: - Property.View (.drain) for Arena

extension Buffer.Arena where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Sequence.Drain.Protocol for Arena.Bounded

extension Buffer.Arena.Bounded: Sequence.Drain.`Protocol` where Element: Copyable {
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let meta = unsafe storage.meta
        Buffer<Element>.Arena.forEach(occupied: header, meta: meta) { slot in
            let element = storage.move(at: slot)
            Buffer<Element>.Arena._releaseSlot(slot, header: &header, meta: meta)
            body(element)
        }
        storage.highWater = .zero
    }
}

// MARK: - Property.View (.drain) for Arena.Bounded

extension Buffer.Arena.Bounded where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
