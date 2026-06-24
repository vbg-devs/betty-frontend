import SwiftUI

/// Full-design toast host for `ToastCenter` (web `NotificationProvider`): stacked cards
/// in insertion order, `★ KICKER` line, optional title, `<strong>`-aware message,
/// X dismisses one alert; confirms show CANCEL / "YES, DO IT →" and never auto-dismiss.
/// Rendered by `ToastOverlay` at the top of `RootView`.
struct LiveToastHost: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: Space.s) {
            ForEach(env.toasts.toasts) { toast in
                LiveToastCard(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.top, Space.xs)
        .animation(.easeOut(duration: 0.25), value: env.toasts.toasts.map(\.id))
        // Without an explicit container the identifier would propagate to every
        // descendant, clobbering the card/button identifiers below.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live.toast.host")
    }
}

struct LiveToastCard: View {
    let toast: ToastCenter.Toast

    @Environment(AppEnvironment.self) private var env
    @Environment(ThemeStore.self) private var theme
    @State private var isWorking = false

    var body: some View {
        BettyInsetPanel(accent: accent) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack(alignment: .top, spacing: Space.s) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("★ \(kicker)")
                            .kicker(accent)
                        if let title = toast.title {
                            Text(title)
                                .font(.betty(15, .heavy))
                                .foregroundStyle(theme.colors.textPrimary)
                        }
                        Text(message)
                            .font(.betty(13, .semibold))
                            .foregroundStyle(theme.colors.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !toast.isConfirm {
                        Button {
                            env.toasts.dismiss(id: toast.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.colors.textMuted)
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("Dismiss")
                        .accessibilityIdentifier("live.toast.dismiss")
                    }
                }
                if toast.isConfirm {
                    HStack(spacing: Space.xs) {
                        Spacer()
                        Button("CANCEL") {
                            env.toasts.dismiss(id: toast.id)
                        }
                        .buttonStyle(.bettyGhost)
                        .disabled(isWorking)
                        .accessibilityIdentifier("live.toast.cancel")
                        Button("YES, DO IT →") {
                            guard !isWorking else { return }
                            isWorking = true
                            Task {
                                await env.toasts.accept(id: toast.id)
                                isWorking = false
                            }
                        }
                        .buttonStyle(.bettyPrimary)
                        .disabled(isWorking)
                        .accessibilityIdentifier("live.toast.confirm")
                    }
                    .padding(.top, Space.xs)
                }
            }
        }
        .shadowLift()
        .onTapGesture {
            if !toast.isConfirm { env.toasts.dismiss(id: toast.id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live.toast.card")
    }

    /// Confirms are always HEADS UP (web overrides any state for confirms).
    private var kicker: String {
        toast.isConfirm ? "HEADS UP" : toast.state.kicker
    }

    /// Web accents: success green, warning yellow, error/critical/info orange. Confirms
    /// carry no state on the web and render the default (orange) accent.
    private var accent: Color {
        if toast.isConfirm { return Palette.orange }
        switch toast.state {
        case .success: return theme.colors.accentPositive
        case .warning: return Palette.yellow
        case .error, .critical, .info: return Palette.orange
        }
    }

    /// `<strong>` runs render heavy + textPrimary (web `.notification__message strong`).
    private var message: AttributedString {
        var text = ToastMessageText.attributed(toast.message)
        let strongRanges = text.runs.compactMap { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true ? run.range : nil
        }
        for range in strongRanges {
            text[range].font = .betty(13, .heavy)
            text[range].foregroundColor = theme.colors.textPrimary
        }
        return text
    }
}
