import Foundation
import Testing
@testable import Betty

/// Pins the web `UpdateProfileModal` image rules: validation order, the 1 MiB cap
/// (exactly 1 MiB OK), exact error copy, 413/415 mapping, revert visibility, and
/// magic-byte sniffing.
@Suite struct ProfileImagePolicyTests {
    @Test func rejectsUnsupportedTypeWithPinnedCopy() {
        let message = ProfileImagePolicy.validationError(contentType: "image/heic", byteCount: 10)
        #expect(message == "Please choose a PNG, JPG, WEBP, or GIF image.")
    }

    @Test func typeCheckWinsOverSizeCheck() {
        // Web validates type first even when the file is also oversized.
        let message = ProfileImagePolicy.validationError(contentType: "application/pdf", byteCount: 5_000_000)
        #expect(message == ProfileImagePolicy.typeMessage)
    }

    @Test func acceptsExactlyOneMiB() {
        let message = ProfileImagePolicy.validationError(contentType: "image/png", byteCount: 1_048_576)
        #expect(message == nil)
    }

    @Test func rejectsOneByteOverTheCap() {
        let message = ProfileImagePolicy.validationError(contentType: "image/png", byteCount: 1_048_577)
        #expect(message == "That image is over 1 MB — please pick a smaller one.")
    }

    @Test func rejectsEmptyFiles() {
        let message = ProfileImagePolicy.validationError(contentType: "image/jpeg", byteCount: 0)
        #expect(message == "That file looks empty. Please choose another image.")
    }

    @Test(arguments: ["image/png", "image/jpeg", "image/webp", "image/gif"])
    func acceptsAllWebAllowedTypes(type: String) {
        #expect(ProfileImagePolicy.validationError(contentType: type, byteCount: 100) == nil)
    }

    @Test func uploadErrorMapping() {
        #expect(ProfileImagePolicy.uploadErrorMessage(status: 413) == ProfileImagePolicy.sizeMessage)
        #expect(ProfileImagePolicy.uploadErrorMessage(status: 415) == ProfileImagePolicy.typeMessage)
        #expect(ProfileImagePolicy.uploadErrorMessage(status: 500) == "Couldn't upload your photo. Please try again.")
        #expect(ProfileImagePolicy.uploadErrorMessage(status: nil) == ProfileImagePolicy.genericUploadMessage)
    }

    @Test func revertHiddenWithoutAnyImage() {
        #expect(!ProfileImagePolicy.hasCustomImage(imageURL: nil, firebaseImageURL: nil))
        #expect(!ProfileImagePolicy.hasCustomImage(imageURL: "", firebaseImageURL: "https://x/y.png"))
    }

    @Test func revertHiddenWhenImageMatchesFirebase() {
        #expect(!ProfileImagePolicy.hasCustomImage(imageURL: "https://x/y.png", firebaseImageURL: "https://x/y.png"))
    }

    @Test func revertShownWhenCustomImageDiffers() {
        #expect(ProfileImagePolicy.hasCustomImage(imageURL: "https://cdn/custom.png", firebaseImageURL: "https://x/y.png"))
    }

    @Test func revertShownWhenThereIsNoFirebaseImage() {
        #expect(ProfileImagePolicy.hasCustomImage(imageURL: "https://cdn/custom.png", firebaseImageURL: nil))
        #expect(ProfileImagePolicy.hasCustomImage(imageURL: "https://cdn/custom.png", firebaseImageURL: ""))
    }

    @Test func sniffsCommonImageMagicBytes() {
        #expect(ProfileImagePolicy.sniffContentType(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) == "image/png")
        #expect(ProfileImagePolicy.sniffContentType(Data([0xFF, 0xD8, 0xFF, 0xE0])) == "image/jpeg")
        #expect(ProfileImagePolicy.sniffContentType(Data("GIF89a".utf8)) == "image/gif")
        var webp = Data("RIFF".utf8)
        webp.append(Data([0x10, 0x00, 0x00, 0x00]))
        webp.append(Data("WEBP".utf8))
        #expect(ProfileImagePolicy.sniffContentType(webp) == "image/webp")
    }

    @Test func sniffReturnsNilForUnknownOrShortData() {
        #expect(ProfileImagePolicy.sniffContentType(Data("hello".utf8)) == nil)
        #expect(ProfileImagePolicy.sniffContentType(Data()) == nil)
        // RIFF container that is NOT webp (e.g. wav).
        var wav = Data("RIFF".utf8)
        wav.append(Data([0x10, 0x00, 0x00, 0x00]))
        wav.append(Data("WAVE".utf8))
        #expect(ProfileImagePolicy.sniffContentType(wav) == nil)
    }
}
