import Foundation
import Testing
@testable import Betty

@Suite struct ChatImageTests {
    @Test func sniffsJPEGMagicBytes() {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        #expect(ChatImage.contentType(of: data) == "image/jpeg")
    }

    @Test func sniffsPNGMagicBytes() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(ChatImage.contentType(of: data) == "image/png")
    }

    @Test func sniffsGIFMagicBytes() {
        #expect(ChatImage.contentType(of: Data("GIF89a-rest".utf8)) == "image/gif")
        #expect(ChatImage.contentType(of: Data("GIF87a-rest".utf8)) == "image/gif")
    }

    @Test func sniffsWebPOnlyWithRIFFAndWEBPMarkers() {
        var webp = Data("RIFF".utf8)
        webp.append(Data([0x10, 0x00, 0x00, 0x00]))
        webp.append(Data("WEBPVP8 ".utf8))
        #expect(ChatImage.contentType(of: webp) == "image/webp")

        var wave = Data("RIFF".utf8)
        wave.append(Data([0x10, 0x00, 0x00, 0x00]))
        wave.append(Data("WAVEfmt ".utf8))
        #expect(ChatImage.contentType(of: wave) == nil)
    }

    @Test func unknownBytesAreRejected() {
        #expect(ChatImage.contentType(of: Data("hello world".utf8)) == nil)
        #expect(ChatImage.contentType(of: Data()) == nil)
    }

    @Test func sizeLimitIsOneMiBAndEmptyFails() {
        #expect(ChatImage.fitsLimit(Data()) == false)
        #expect(ChatImage.fitsLimit(Data(count: ChatImage.maxBytes)) == true)
        #expect(ChatImage.fitsLimit(Data(count: ChatImage.maxBytes + 1)) == false)
    }

    @Test func allowedTypesMatchThePresignContract() {
        #expect(ChatImage.allowedContentTypes == ["image/jpeg", "image/png", "image/webp", "image/gif"])
    }
}
