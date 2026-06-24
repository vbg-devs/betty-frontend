import Foundation
import Observation

/// Global toast / confirm queue (web `useNotify`).
///
/// Alerts auto-dismiss after 4 s (pinned); confirms never auto-dismiss and await their
/// (possibly async) `onConfirm` before dismissing. Kicker copy by state:
/// success → NICE, error/critical → OOPS, warning → HEADS UP, info → BETTY SAYS;
/// confirms are always HEADS UP.
@Observable
final class ToastCenter {
    enum State: String {
        case success, error, warning, info, critical

        var kicker: String {
            switch self {
            case .success: "NICE"
            case .error, .critical: "OOPS"
            case .warning: "HEADS UP"
            case .info: "BETTY SAYS"
            }
        }
    }

    struct Toast: Identifiable {
        let id: Int
        let title: String?
        let message: String
        let state: State
        let isConfirm: Bool
        let onConfirm: (@MainActor () async -> Void)?
    }

    private(set) var toasts: [Toast] = []
    private var nextID = 0
    private let autoDismissSeconds: Double

    init(autoDismissSeconds: Double = 4) {
        self.autoDismissSeconds = autoDismissSeconds
    }

    /// Transient alert — auto-dismisses after 4 s; manual dismiss supported.
    func alert(title: String? = nil, message: String, state: State = .info) {
        let id = enqueue(Toast(id: nextID, title: title, message: message, state: state, isConfirm: false, onConfirm: nil))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.autoDismissSeconds ?? 4))
            self?.dismiss(id: id)
        }
    }

    /// Confirm prompt — stays until CANCEL (no callback) or YES (awaits `onConfirm`,
    /// then dismisses; the toast stays visible during the async work).
    func confirm(title: String? = nil, question: String, onConfirm: @escaping @MainActor () async -> Void) {
        _ = enqueue(Toast(id: nextID, title: title, message: question, state: .warning, isConfirm: true, onConfirm: onConfirm))
    }

    func dismiss(id: Int) {
        toasts.removeAll { $0.id == id }
    }

    func clearAll() {
        toasts = []
    }

    /// Accept a confirm: awaits the callback, then dismisses.
    func accept(id: Int) async {
        guard let toast = toasts.first(where: { $0.id == id }) else { return }
        if let onConfirm = toast.onConfirm {
            await onConfirm()
        }
        dismiss(id: id)
    }

    private func enqueue(_ toast: Toast) -> Int {
        toasts.append(toast)
        nextID += 1
        return toast.id
    }
}
