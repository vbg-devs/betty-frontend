import SwiftUI
import UIKit

/// Stroke-only display text — the web hero's outlined treatment
/// (`-webkit-text-stroke`, e.g. the landing "KEEP SCORE."). SwiftUI has no text-stroke
/// primitive, so this wraps a `UILabel` with an attributed stroke: a positive
/// `strokeWidth` renders the outline only, leaving the glyph fill transparent.
struct OutlinedDisplayText: UIViewRepresentable {
    let text: String
    var size: CGFloat = 40
    var weight: UIFont.Weight = .black
    var color: Color
    /// Stroke width as a percentage of the font point size (UIKit semantics).
    var strokeWidthPercent: CGFloat = 4

    init(
        _ text: String,
        size: CGFloat = 40,
        weight: UIFont.Weight = .black,
        color: Color,
        strokeWidthPercent: CGFloat = 4
    ) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.strokeWidthPercent = strokeWidthPercent
    }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                // Display tracking matches `displayKerning`: size * -0.02.
                .kern: size * -0.02,
                .strokeColor: UIColor(color),
                .strokeWidth: strokeWidthPercent,
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        return uiView.sizeThatFits(CGSize(width: width, height: UIView.layoutFittingExpandedSize.height))
    }
}
