// Core module: struct declarations with package visibility stored properties
// UPDATED: Core now provides memberwise init (since cross-module init is forbidden)

public enum Container {}

extension Container {
    public enum Ring {}
}

extension Container.Ring {
    public struct Header: Sendable {
        public var count: Int
        public let capacity: Int

        @inlinable
        public init(capacity: Int) {
            self.count = 0
            self.capacity = capacity
        }

        @inlinable
        public var isEmpty: Bool { count == 0 }
    }
}

// V1: ~Copyable struct — Core provides memberwise init
extension Container.Ring {
    public struct Growable<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: [Int]  // simplified stand-in

        @inlinable
        package init(header: Header, storage: [Int]) {
            self.header = header
            self.storage = storage
        }
    }
}

extension Container.Ring.Growable: Copyable where Element: Copyable {}
extension Container.Ring.Growable: @unchecked Sendable where Element: Sendable {}

// V2: Another ~Copyable struct — Core provides memberwise init
extension Container.Ring {
    public struct Bounded<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var value: Int

        @inlinable
        package init(header: Header, value: Int) {
            self.header = header
            self.value = value
        }
    }
}

extension Container.Ring.Bounded: Copyable where Element: Copyable {}
extension Container.Ring.Bounded: @unchecked Sendable where Element: Sendable {}

// V5: ~Copyable struct with deinit — tests that deinit stays in Core
// Key finding: deinit has IMMUTABLE self — cannot call mutating methods
extension Container.Ring {
    public struct Draining<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: [Int]

        @inlinable
        package init(header: Header, storage: [Int]) {
            self.header = header
            self.storage = storage
        }

        deinit {
            // V5a: Can deinit READ stored properties?
            let _ = header.count      // read-only access
            let _ = storage.count     // read-only access
            // V5b: Can deinit call mutating methods? NO — self is immutable
            // storage.removeAll()    // ERROR: cannot use mutating member
            // header.count = 0       // ERROR: cannot assign to property
        }
    }
}

// V5 cannot be Copyable (has deinit)
extension Container.Ring.Draining: @unchecked Sendable where Element: Sendable {}

// V6: ~Copyable struct with consuming deinit approach
// Test: can we use a consuming method called before deinit to clean up?
extension Container.Ring {
    public struct SlabLike<Element: ~Copyable>: ~Copyable {
        @usableFromInline
        package var header: Header

        @usableFromInline
        package var storage: [Int]

        @inlinable
        package init(header: Header, storage: [Int]) {
            self.header = header
            self.storage = storage
        }

        // No deinit — relies on Storage.Heap's own deinit via .initialization sync
        // For Slab: must call explicit cleanup before dropping
    }
}

extension Container.Ring.SlabLike: @unchecked Sendable where Element: Sendable {}
