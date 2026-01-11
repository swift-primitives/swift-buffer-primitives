import Binary_Primitives
import Test_Primitives
import Testing_Extras

@testable import Buffer_Primitives

// Tests for Buffer.Aligned conformance to Binary.Contiguous/Mutable.
// Array/ContiguousArray conformance tests are in swift-standards.

extension Buffer {
    enum BinaryConformance {
        #TestSuites
    }
}

// MARK: - Byte Accessor Unit Tests

extension Buffer.BinaryConformance.Test.Unit {
    @Test("byte.at reads correct value")
    func byteAtReadsValue() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            ptr[5] = 0xAB
        }

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(5)
        let value = try buffer.byte.at(position)
        #expect(value == 0xAB)
    }

    @Test("byte.set writes correct value")
    func byteSetWritesValue() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 16, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(7)
        try buffer.byte.set(0xCD, at: position)

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[7] == 0xCD)
        }
    }

    @Test("byte.at throws on out of bounds")
    func byteAtThrowsOutOfBounds() throws {
        let buffer = try Buffer.Aligned(byteCount: 8, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(10)
        #expect(throws: Binary.Error.self) {
            try buffer.byte.at(position)
        }
    }

    @Test("byte.set throws on out of bounds")
    func byteSetThrowsOutOfBounds() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 8, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(10)
        #expect(throws: Binary.Error.self) {
            try buffer.byte.set(0xFF, at: position)
        }
    }

    @Test("byte.at throws on negative position")
    func byteAtThrowsNegativePosition() throws {
        let buffer = try Buffer.Aligned(byteCount: 8, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(-1)
        #expect(throws: Binary.Error.self) {
            try buffer.byte.at(position)
        }
    }

    @Test("unchecked byte.at reads correct value")
    func uncheckedByteAtReadsValue() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            ptr[3] = 0x99
        }

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(3)
        let value = buffer.byte.at(__unchecked: (), position)
        #expect(value == 0x99)
    }

    @Test("unchecked byte.set writes correct value")
    func uncheckedByteSetWritesValue() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 16, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(11)
        buffer.byte.set(__unchecked: (), 0x77, at: position)

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[11] == 0x77)
        }
    }

    @Test("subscript reads correct value")
    func subscriptReadsValue() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            ptr[2] = 0xEE
        }

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(2)
        #expect(buffer[position] == 0xEE)
    }

    @Test("subscript writes correct value")
    func subscriptWritesValue() throws {
        var buffer = try Buffer.Aligned.zeroed(byteCount: 16, alignment: .doubleWord)

        let position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(9)
        buffer[position] = 0xDD

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[9] == 0xDD)
        }
    }
}

// MARK: - Range Access Unit Tests

extension Buffer.BinaryConformance.Test.Unit {
    @Test("withBytes(in:) provides correct span")
    func withBytesInRangeCorrectSpan() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<16 { ptr[i] = UInt8(i) }
        }

        let start = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(4)
        let end = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(8)

        try buffer.withBytes(in: start..<end) { span in
            #expect(span.count == 4)
            for i in 0..<4 {
                #expect(span[i] == UInt8(i + 4))
            }
        }
    }

    @Test("withBytes(in:) throws on out of bounds")
    func withBytesInRangeThrowsOutOfBounds() throws {
        let buffer = try Buffer.Aligned(byteCount: 8, alignment: .doubleWord)

        let start = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(4)
        let end = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(12)

        #expect(throws: Buffer.Aligned.BytesRangeError<Never>.self) {
            try buffer.withBytes(in: start..<end) { _ in }
        }
    }

    @Test("unchecked withBytes(in:) provides correct span")
    func uncheckedWithBytesInRange() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<16 { ptr[i] = UInt8(i * 2) }
        }

        let start = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(2)
        let end = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>(6)

        buffer.withBytes(__unchecked: (), in: start..<end) { span in
            #expect(span.count == 4)
            #expect(span[0] == 4)  // 2 * 2
            #expect(span[1] == 6)  // 3 * 2
        }
    }
}

// MARK: - Binary.Cursor Integration Tests

extension Buffer.BinaryConformance.Test.Unit {
    typealias Position = Binary.Position<Buffer.Aligned.Scalar, Buffer.Aligned.Space>
    typealias Offset = Binary.Offset<Buffer.Aligned.Scalar, Buffer.Aligned.Space>

    @Test("Binary.Cursor can be created over Buffer.Aligned")
    func cursorCreation() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 64, alignment: .quadWord)
        let cursor = try Binary.Cursor(storage: buffer)

        #expect(cursor.count == 64)
        #expect(cursor.readerIndex == Position(0))
        #expect(cursor.writerIndex == Position(0))
    }

    @Test("Binary.Cursor tracks readable/writable counts")
    func cursorReadableWritable() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 32, alignment: .doubleWord)
        var cursor = try Binary.Cursor(
            storage: buffer,
            readerIndex: Position(0),
            writerIndex: Position(20)
        )

        #expect(cursor.readableCount == 20)
        #expect(cursor.writableCount == 12)
        #expect(cursor.isReadable == true)
        #expect(cursor.isWritable == true)

        try cursor.setWriterIndex(to: Position(32))
        #expect(cursor.isWritable == false)
    }

    @Test("Binary.Cursor move operations work")
    func cursorMoveOperations() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 100, alignment: .quadWord)
        var cursor = try Binary.Cursor(storage: buffer)

        // Move writer forward
        try cursor.moveWriterIndex(by: Offset(50))
        #expect(cursor.writerIndex.rawValue == 50)

        // Move reader forward
        try cursor.moveReaderIndex(by: Offset(25))
        #expect(cursor.readerIndex.rawValue == 25)
        #expect(cursor.readableCount == 25)

        // Reset
        cursor.reset()
        #expect(cursor.readerIndex == Position(0))
        #expect(cursor.writerIndex == Position(0))
    }

    @Test("Binary.Cursor enforces invariants")
    func cursorInvariantEnforcement() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 32, alignment: .doubleWord)
        var cursor = try Binary.Cursor(
            storage: buffer,
            readerIndex: Position(10),
            writerIndex: Position(20)
        )

        // Cannot move reader past writer
        #expect(throws: Binary.Error.self) {
            try cursor.moveReaderIndex(by: Offset(15))
        }

        // Cannot move writer past count
        #expect(throws: Binary.Error.self) {
            try cursor.moveWriterIndex(by: Offset(20))
        }

        // Cannot set reader negative
        #expect(throws: Binary.Error.self) {
            try cursor.setReaderIndex(to: Position(-5))
        }
    }

    @Test("Binary.Cursor provides region access")
    func cursorRegionAccess() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .doubleWord)
        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<16 { ptr[i] = UInt8(i) }
        }

        var cursor = try Binary.Cursor(
            storage: buffer,
            readerIndex: Position(4),
            writerIndex: Position(12)
        )

        // Readable region is [4..<12]
        cursor.withReadableBytes { ptr in
            #expect(ptr.count == 8)
            #expect(ptr[0] == 4)
            #expect(ptr[7] == 11)
        }

        // Writable region is [12..<16]
        cursor.withWritableBytes { ptr in
            #expect(ptr.count == 4)
            ptr[0] = 0xFF
        }

        // Verify write took effect
        cursor.storage.withUnsafeBytes { ptr in
            #expect(ptr[12] == 0xFF)
        }
    }
}

// MARK: - Conformance Unit Tests

extension Buffer.BinaryConformance.Test.Unit {
    @Test("Buffer.Aligned conforms to Binary.Contiguous")
    func alignedConformsToContiguous() throws {
        var buffer = try Buffer.Aligned(byteCount: 16, alignment: .quadWord)

        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<16 {
                ptr[i] = UInt8(i)
            }
        }

        buffer.withUnsafeBytes { ptr in
            #expect(ptr.count == 16)
            #expect(ptr[0] == 0)
            #expect(ptr[15] == 15)
        }
    }

    @Test("Buffer.Aligned conforms to Binary.Mutable")
    func alignedConformsToMutable() throws {
        var buffer = try Buffer.Aligned.zeroed(byteCount: 8, alignment: .doubleWord)

        buffer.withUnsafeMutableBytes { ptr in
            ptr[0] = 0xFF
        }

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[0] == 0xFF)
        }
    }

    @Test("Buffer.Aligned count satisfies Binary.Contiguous requirement")
    func alignedCountProperty() throws {
        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .sector512)
        #expect(buffer.count == 1024)

        buffer.withUnsafeBytes { ptr in
            #expect(ptr.count == buffer.count)
        }
    }

    @Test("generic function accepts Buffer.Aligned as Binary.Contiguous")
    func genericContiguousFunction() throws {
        func readFirstByte<T: Binary.Contiguous & ~Copyable>(
            _ bytes: borrowing T
        ) -> UInt8 {
            bytes.withUnsafeBytes { ptr in
                ptr.first ?? 0
            }
        }

        var aligned = try Buffer.Aligned(byteCount: 16, alignment: .quadWord)
        aligned.withUnsafeMutableBytes { $0[0] = 0x44 }

        #expect(readFirstByte(aligned) == 0x44)
    }

    @Test("generic function accepts Buffer.Aligned as Binary.Mutable")
    func genericMutableFunction() throws {
        func writeFirstByte<T: Binary.Mutable & ~Copyable>(
            _ bytes: inout T,
            value: UInt8
        ) {
            bytes.withUnsafeMutableBytes { ptr in
                if !ptr.isEmpty {
                    ptr[0] = value
                }
            }
        }

        var aligned = try Buffer.Aligned.zeroed(byteCount: 16, alignment: .quadWord)

        writeFirstByte(&aligned, value: 0xCC)

        aligned.withUnsafeBytes { #expect($0[0] == 0xCC) }
    }
}
