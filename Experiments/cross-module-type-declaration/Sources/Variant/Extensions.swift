// Variant module: extensions adding convenience init, methods, and protocol
// conformances to Core types via delegating to Core's package memberwise init.

public import Core

// V1: Convenience init that delegates to Core's package memberwise init
extension Container.Ring.Growable {
    @inlinable
    public init(capacity: Int) {
        self.init(
            header: Container.Ring.Header(capacity: capacity),
            storage: []
        )
    }

    @inlinable
    public var count: Int { header.count }

    @inlinable
    public var isEmpty: Bool { header.isEmpty }

    @inlinable
    public mutating func push(_ value: Int) where Element == Int {
        storage.append(value)
        header.count += 1
    }

    @inlinable
    public mutating func removeAll() {
        storage.removeAll()
        header.count = 0
    }
}

// V2: Convenience init for Bounded — same delegation pattern
extension Container.Ring.Bounded {
    @inlinable
    public init(capacity: Int) {
        self.init(
            header: Container.Ring.Header(capacity: capacity),
            value: 0
        )
    }

    @inlinable
    public var count: Int { header.count }
}

// V3: Protocol conformance from variant module
public protocol Drainable: ~Copyable {
    associatedtype Element
    mutating func drain(_ body: (consuming Element) -> Void)
}

extension Container.Ring.Growable: Drainable where Element == Int {
    @inlinable
    public mutating func drain(_ body: (consuming Int) -> Void) {
        for v in storage {
            body(v)
        }
        storage.removeAll()
        header.count = 0
    }
}

// V5: Convenience init for type with deinit in Core
extension Container.Ring.Draining {
    @inlinable
    public init(capacity: Int) {
        self.init(
            header: Container.Ring.Header(capacity: capacity),
            storage: []
        )
    }

    @inlinable
    public var count: Int { header.count }

    @inlinable
    public mutating func push(_ value: Int) where Element == Int {
        storage.append(value)
        header.count += 1
    }
}

// V6: SlabLike — consuming cleanup method from Variant
extension Container.Ring.SlabLike {
    @inlinable
    public init(capacity: Int) {
        self.init(
            header: Container.Ring.Header(capacity: capacity),
            storage: []
        )
    }

    @inlinable
    public var count: Int { header.count }

    @inlinable
    public mutating func insert(_ value: Int) where Element == Int {
        storage.append(value)
        header.count += 1
    }

    /// Explicit cleanup — simulates Slab's bitmap-driven deinit
    @inlinable
    public mutating func deinitializeAll() {
        storage.removeAll()
        header.count = 0
    }
}
