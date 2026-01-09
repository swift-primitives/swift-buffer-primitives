import Binary_Primitives
import Test_Support_Primitives
import Testing

@testable import Buffer_Primitives

extension Buffer.Aligned {
    #TestSuites
}

// MARK: - Unit Tests

extension Buffer.Aligned.Test.Unit {
    @Test("allocates with valid parameters")
    func allocatesWithValidParameters() throws {
        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .sector512)
        #expect(buffer.count == 1024)
        #expect(buffer.alignment == .sector512)
    }

    @Test("allocates zeroed buffer")
    func allocatesZeroedBuffer() throws {
        let buffer = try Buffer.Aligned.zeroed(byteCount: 1024, alignment: .sector512)
        buffer.withUnsafeBytes { ptr in
            for byte in ptr {
                #expect(byte == 0)
            }
        }
    }

    @Test("allocates page-aligned buffer")
    func allocatesPageAlignedBuffer() throws {
        let buffer = try Buffer.Aligned.pageAligned(byteCount: 4096)
        #expect(buffer.count == 4096)
        #expect(buffer.alignment == Buffer.Memory.pageAlignment)
        let aligned = buffer.isAligned(to: Buffer.Memory.pageAlignment)
        #expect(aligned)
    }

    @Test("isAligned returns true for guaranteed alignment")
    func isAlignedToGuaranteed() throws {
        let buffer = try Buffer.Aligned(byteCount: 4096, alignment: .sector512)
        let aligned = buffer.isAligned(to: .sector512)
        #expect(aligned)
    }

    @Test("isAligned returns true for smaller alignments")
    func isAlignedToSmaller() throws {
        let buffer = try Buffer.Aligned(byteCount: 4096, alignment: .sector512)
        let alignments: [Binary.Alignment] = [.byte, .halfWord, .word, .doubleWord, .quadWord]
        for boundary in alignments {
            let aligned = buffer.isAligned(to: boundary)
            #expect(aligned)
        }
    }

    @Test("withUnsafeBytes provides correct buffer")
    func withUnsafeBytesAccess() throws {
        var buffer = try Buffer.Aligned(byteCount: 1024, alignment: .sector512)

        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<ptr.count {
                ptr[i] = UInt8(i % 256)
            }
        }

        buffer.withUnsafeBytes { ptr in
            #expect(ptr.count == 1024)
            for i in 0..<ptr.count {
                #expect(ptr[i] == UInt8(i % 256))
            }
        }
    }

    @Test("withUnsafeMutableBytes allows modification")
    func withUnsafeMutableBytesAccess() throws {
        var buffer = try Buffer.Aligned.zeroed(byteCount: 1024, alignment: .sector512)

        buffer.withUnsafeMutableBytes { ptr in
            ptr[0] = 0xAB
            ptr[1] = 0xCD
        }

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[0] == 0xAB)
            #expect(ptr[1] == 0xCD)
        }
    }

    @Test("typed throwing closure propagates error")
    func typedThrowingClosure() throws {
        enum TestError: Error { case expected }

        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .sector512)

        #expect(throws: TestError.expected) {
            try buffer.withUnsafeBytes { (_: UnsafeRawBufferPointer) throws(TestError) in
                throw TestError.expected
            }
        }
    }

    @Test(
        "accepts power-of-2 alignments",
        arguments: [
            Binary.Alignment.doubleWord, .quadWord,
            .sector512, .`1024`, .page4096
        ]
    )
    func acceptsValidAlignment(alignment: Binary.Alignment) throws {
        let size: Int = alignment.magnitude()
        let buffer = try Buffer.Aligned(byteCount: size, alignment: alignment)
        #expect(buffer.alignment == alignment)
    }
}

// MARK: - Edge Cases

extension Buffer.Aligned.Test.EdgeCase {
    @Test("allows zero size (empty buffer)")
    func allowsZeroSize() throws {
        let buffer = try Buffer.Aligned(byteCount: 0, alignment: .sector512)
        // swiftlint:disable:next empty_count
        #expect(buffer.count == 0)
        #expect(buffer.alignment == .sector512)
    }

    @Test("rejects negative size")
    func rejectsNegativeSize() {
        #expect(throws: Buffer.Aligned.Error.invalidSize) {
            _ = try Buffer.Aligned(byteCount: -1, alignment: .sector512)
        }
    }

    // Note: Tests for invalid alignment (non-power-of-2, below minimum) are no longer needed
    // because Binary.Alignment guarantees the value is a valid power of 2 at compile time.

    @Test("withMisalignedView creates offset pointer")
    func misalignedViewOffset() throws {
        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .sector512)

        buffer.withMisalignedView(offset: 1) { misaligned in
            #expect(misaligned.count == 1023)
            let aligned = isAligned(misaligned.baseAddress, to: 512)
            #expect(!aligned)
        }
    }

    @Test("withMisalignedMutableView creates offset pointer")
    func misalignedMutableViewOffset() throws {
        var buffer = try Buffer.Aligned.zeroed(byteCount: 1024, alignment: .sector512)

        buffer.withMisalignedMutableView(offset: 7) { misaligned in
            #expect(misaligned.count == 1017)
            misaligned[0] = 0xFF
        }

        buffer.withUnsafeBytes { ptr in
            #expect(ptr[7] == 0xFF)
        }
    }
}

// MARK: - Helper

private func isAligned(_ pointer: UnsafeRawPointer?, to boundary: Int) -> Bool {
    guard let pointer = pointer else { return false }
    return Int(bitPattern: pointer) % boundary == 0
}
