//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 02/02/2026.
//

public import Buffer_Primitives_Core
public import Buffer_Ring_Primitives

extension Buffer.Ring.Static where Element: Copyable {
    /// Returns a copy of the front element without removing it.
    ///
    /// - Returns: A copy of the front element, or `nil` if the buffer is empty.
    @inlinable
    public func peekFront() -> Element? {
        withFront { $0 }
    }

    /// Returns a copy of the back element without removing it.
    ///
    /// - Returns: A copy of the back element, or `nil` if the buffer is empty.
    @inlinable
    public func peekBack() -> Element? {
        withBack { $0 }
    }
}
