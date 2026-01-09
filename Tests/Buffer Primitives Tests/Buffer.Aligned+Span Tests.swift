import Binary_Primitives
import Testing

@testable import Buffer_Primitives

// MARK: - Empty Buffer Tests

@Suite("Buffer.Aligned Empty Buffer")
struct BufferAlignedEmptyBufferTests {
    @Test("empty buffer has valid pointer")
    func emptyBufferPointer() throws {
        let buffer = try Buffer.Aligned(byteCount: 0, alignment: .doubleWord)
        buffer.withUnsafeBytes { ptr in
            #expect(ptr.baseAddress != nil)
            // swiftlint:disable:next empty_count
            #expect(ptr.count == 0)
        }
    }

    @Test("empty buffer bytes span has zero count")
    func emptyBufferBytesSpan() throws {
        let buffer = try Buffer.Aligned(byteCount: 0, alignment: .doubleWord)
        let span = buffer.bytes
        // swiftlint:disable:next empty_count
        #expect(span.count == 0)
    }

    @Test("empty buffer withRawSpan has zero byteCount")
    func emptyBufferRawBytesSpan() throws {
        let buffer = try Buffer.Aligned(byteCount: 0, alignment: .doubleWord)
        buffer.withRawSpan { span in
            #expect(span.byteCount == 0)
        }
    }

    @Test("multiple empty buffers share sentinel")
    func emptyBuffersShareSentinel() throws {
        let buffer1 = try Buffer.Aligned(byteCount: 0, alignment: .doubleWord)
        let buffer2 = try Buffer.Aligned(byteCount: 0, alignment: .quadWord)
        let buffer3 = try Buffer.Aligned(byteCount: 0, alignment: .page4096)

        var ptr1: UnsafeRawPointer?
        var ptr2: UnsafeRawPointer?
        var ptr3: UnsafeRawPointer?

        buffer1.withUnsafeBytes { ptr1 = $0.baseAddress }
        buffer2.withUnsafeBytes { ptr2 = $0.baseAddress }
        buffer3.withUnsafeBytes { ptr3 = $0.baseAddress }

        #expect(ptr1 == ptr2)
        #expect(ptr2 == ptr3)
    }
}

// MARK: - Typed Span Tests

@Suite("Buffer.Aligned Span<UInt8>")
struct BufferAlignedSpanTests {
    @Test("bytes returns Span with correct count")
    func bytesSpan() throws {
        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .doubleWord)
        let span = buffer.bytes
        #expect(span.count == 1024)
    }

    @Test("mutableBytes returns MutableSpan with correct count")
    func mutableBytesSpan() throws {
        var buffer = try Buffer.Aligned(byteCount: 1024, alignment: .doubleWord)
        let span = buffer.mutableBytes
        #expect(span.count == 1024)
    }

    @Test("mutableBytes allows writing and reading back")
    func mutableBytesWriteRead() throws {
        var buffer = try Buffer.Aligned.zeroed(byteCount: 16, alignment: .doubleWord)
        var span = buffer.mutableBytes
        span[0] = 0xDE
        span[1] = 0xAD
        span[2] = 0xBE
        span[3] = 0xEF

        #expect(buffer.bytes[0] == 0xDE)
        #expect(buffer.bytes[1] == 0xAD)
        #expect(buffer.bytes[2] == 0xBE)
        #expect(buffer.bytes[3] == 0xEF)
    }

    @Test("bytes span matches withUnsafeBytes content")
    func bytesMatchesUnsafeBytes() throws {
        var buffer = try Buffer.Aligned(byteCount: 256, alignment: .doubleWord)

        // Write pattern
        buffer.withUnsafeMutableBytes { ptr in
            for i in 0..<ptr.count {
                ptr[i] = UInt8(i)
            }
        }

        // Verify via span
        let span = buffer.bytes
        for i in 0..<span.count {
            #expect(span[i] == UInt8(i))
        }
    }
}

// MARK: - Raw Span Tests (Closure-Based)

@Suite("Buffer.Aligned RawSpan")
struct BufferAlignedRawSpanTests {
    @Test("withRawSpan provides RawSpan with correct byteCount")
    func rawBytesSpan() throws {
        let buffer = try Buffer.Aligned(byteCount: 1024, alignment: .doubleWord)
        buffer.withRawSpan { span in
            #expect(span.byteCount == 1024)
        }
    }

    @Test("withMutableRawSpan provides MutableRawSpan with correct byteCount")
    func mutableRawBytesSpan() throws {
        var buffer = try Buffer.Aligned(byteCount: 1024, alignment: .doubleWord)
        buffer.withMutableRawSpan { span in
            #expect(span.byteCount == 1024)
        }
    }
}
