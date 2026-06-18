import ImageIO
import SwiftUI
import UIKit

/// Animated remote image — SwiftUI's `AsyncImage` renders only the first frame of a
/// GIF, so the chat meme board reused it and got a still image. This view decodes the
/// full GIF via ImageIO and plays it through `UIImageView`'s animated-images API;
/// non-animated payloads (JPEG/PNG/WebP single frame) render as a regular image.
struct AnimatedImageView: View {
    let url: URL?

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Rep(image: image)
            .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if Task.isCancelled { return }
            if let decoded = Self.decode(data) {
                image = decoded
            } else {
                failed = true
            }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    /// ImageIO walks every frame and reads the per-frame delay (clamped to 100 ms ÷ 10 ≈
    /// the 50 ms floor browsers use, so we don't end up with absurdly fast GIFs).
    private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        if count <= 1 {
            return UIImage(data: data)
        }
        var frames: [UIImage] = []
        frames.reserveCapacity(count)
        var totalDuration: TimeInterval = 0
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            totalDuration += frameDelay(source: source, index: index)
        }
        if frames.isEmpty { return UIImage(data: data) }
        if totalDuration <= 0 { totalDuration = Double(frames.count) * 0.1 }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }

    private struct Rep: UIViewRepresentable {
        let image: UIImage?

        func makeUIView(context: Context) -> UIImageView {
            let view = UIImageView()
            view.contentMode = .scaleAspectFit
            view.clipsToBounds = true
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentHuggingPriority(.defaultLow, for: .vertical)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            return view
        }

        func updateUIView(_ uiView: UIImageView, context: Context) {
            uiView.image = image
            if let image, image.images != nil {
                uiView.animationImages = image.images
                uiView.animationDuration = image.duration
                uiView.animationRepeatCount = 0
                uiView.startAnimating()
            } else {
                uiView.stopAnimating()
                uiView.animationImages = nil
            }
        }
    }
}
