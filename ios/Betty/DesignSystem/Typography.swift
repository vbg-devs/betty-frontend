import SwiftUI

/// Betty type scale — system font (SF Pro), identity lives in the heavy/black weights,
/// uppercase + wide tracking for kickers, tight negative tracking for big numerals,
/// tabular numerals for scores.
nonisolated extension Font {
    static func betty(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// 64/.black — hero titles (clamp 48–72 by width/Dynamic Type).
    static let bettyDisplayXL = betty(64, .black)
    /// 40/.black — section heads.
    static let bettyDisplayL = betty(40, .black)
    /// 32/.black — modal/page titles.
    static let bettyTitle1 = betty(32, .black)
    /// 28/.black — group-card titles.
    static let bettyTitle2 = betty(28, .black)
    /// 22/.black — leaderboard place numerals.
    static let bettyTitle3 = betty(22, .black)
    /// 17/.heavy — stacked-row names.
    static let bettyHeadline = betty(17, .heavy)
    /// 15/.semibold — body copy.
    static let bettyBody = betty(15, .semibold)
    /// 14/.bold — bet rows, ledes.
    static let bettySubhead = betty(14, .bold)
    /// 12/.heavy — nav links, tabs, team names (UPPER, +1.6 / +0.6 tracking).
    static let bettyCaption = betty(12, .heavy)
    /// 11/.heavy — kickers, badges, button labels (UPPER, +1.6).
    static let bettyKicker = betty(11, .heavy)
    /// 10/.heavy — "YOU" badge, countdown units, tab counts (UPPER, +1.2–1.4).
    static let bettyMicro = betty(10, .heavy)
    /// 56/.black tabular — bet-modal score input.
    static let bettyScoreXL = Font.system(size: 56, weight: .black).monospacedDigit()
    /// 28/.black tabular — game tile score.
    static let bettyScore = Font.system(size: 28, weight: .black).monospacedDigit()
    /// 26/.black tabular — leaderboard points.
    static let bettyScoreRow = Font.system(size: 26, weight: .black).monospacedDigit()
}

/// THE most reused style: 11pt heavy UPPERCASE with +1.6 kerning.
struct Kicker: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .font(.bettyKicker)
            .kerning(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func kicker(_ color: Color) -> some View {
        modifier(Kicker(color: color))
    }

    /// Display/score tracking: `size * -0.02`.
    func displayKerning(_ size: CGFloat) -> some View {
        kerning(size * -0.02)
    }
}
