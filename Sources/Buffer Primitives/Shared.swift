//
//  Shared.swift
//  swift-buffer
//
//  Created by Coen ten Thije Boonkkamp on 07/01/2026.
//

/// A reference wrapper that provides shared access to a value.
///
/// `Shared` boxes a value (including noncopyable types) in a reference type,
/// enabling multiple owners to share access to the same underlying storage.
///
/// ## Thread Safety
///
/// `Shared` itself provides no synchronization. If the boxed value needs
/// thread-safe access, it must provide its own synchronization (e.g., `Mutex`).
///
/// For thread-safe shared queues, use `Shared<Mutex<Deque<T>>>` with the
/// queue extensions.
///
/// ## Usage
///
/// ```swift
/// // Shared mutable state
/// let counter = Shared(0)
/// counter.withValue { $0 += 1 }
///
/// // Shared synchronized queue
/// let queue: Shared<Mutex<Deque<Int>>> = .init(.init(.init()))
/// queue.enqueue(1)
/// let item = queue.dequeue()
/// ```
public final class Shared<Value: ~Copyable> {
    @usableFromInline
    var _value: Value

    /// Creates a shared reference to the given value.
    ///
    /// - Parameter value: The value to box.
    @inlinable
    public init(_ value: consuming Value) {
        self._value = value
    }

    /// Accesses the value for reading.
    ///
    /// - Parameter body: A closure that receives the value.
    /// - Returns: The result of the closure.
    @inlinable
    public func withValue<Result>(
        _ body: (borrowing Value) throws -> Result
    ) rethrows -> Result {
        try body(_value)
    }

    /// Accesses the value for mutation.
    ///
    /// - Parameter body: A closure that receives an inout reference to the value.
    /// - Returns: The result of the closure.
    @inlinable
    public func update<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        try body(&_value)
    }
}

extension Shared: @unchecked Sendable where Value: Sendable {}
