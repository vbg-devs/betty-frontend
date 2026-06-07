import UIKit

/// Fits a picked photo into the presign constraints (1 MiB, jpeg/png/webp/gif):
/// passes supported small files through untouched, otherwise downscales + re-encodes
/// as JPEG. nil = not an image we can send.
nonisolated enum ChatPhotoPreparer {
    // @concurrent: the downscale/re-encode loop takes seconds for camera photos and
    // must stay off the main actor (UIGraphicsImageRenderer/jpegData are thread-safe).
    @concurrent
    static func prepare(_ raw: Data) async -> (data: Data, contentType: String)? {
        if let type = ChatImage.contentType(of: raw), ChatImage.fitsLimit(raw) {
            return (raw, type)
        }
        guard let image = UIImage(data: raw) else { return nil }
        var dimension: CGFloat = 1600
        while dimension >= 200 {
            let scaled = image.scaledToFit(maxDimension: dimension)
            var quality: CGFloat = 0.8
            while quality >= 0.25 {
                if let jpeg = scaled.jpegData(compressionQuality: quality), ChatImage.fitsLimit(jpeg) {
                    return (jpeg, "image/jpeg")
                }
                quality -= 0.25
            }
            dimension /= 2
        }
        return nil
    }
}

private nonisolated extension UIImage {
    func scaledToFit(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension, largest > 0 else { return self }
        let factor = maxDimension / largest
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
