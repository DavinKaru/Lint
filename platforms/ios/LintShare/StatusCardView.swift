import Observation
import SwiftUI

/// Drives `StatusCardView`: set by `ShareViewController` as the share moves along.
@MainActor @Observable
final class StatusCardModel {
    enum Phase: Equatable {
        /// A short link is being resolved over the network.
        case resolving
        /// Done; the share sheet is (re)opening with the result.
        case done(Outcome)
    }

    enum Outcome: Equatable {
        /// Tracking was stripped from the link.
        case cleaned
        /// There was a link, but nothing to strip from it.
        case alreadyClean
        /// The shared text had no link in it, so it's passed on unchanged.
        case noLink
    }

    /// Nil until the share has been read, so nothing flashes up before there's anything to show.
    var phase: Phase?
}

/// The small status card: a spinner while a short link resolves, then a confirmation that the
/// link was cleaned, which stays behind the re-opened share sheet so the share extension's system
/// sheet isn't left empty. Liquid Glass on iOS 26+, the standard system material before that.
struct StatusCardView: View {
    let model: StatusCardModel

    var body: some View {
        if let phase = model.phase {
            VStack(spacing: 16) {
                Group {
                    switch phase {
                    case .resolving:
                        ProgressView()
                            .controlSize(.large)
                    case .done:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.tint)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 44)

                VStack(spacing: 4) {
                    Text(title(for: phase))
                        .font(.headline)
                    if let subtitle = subtitle(for: phase) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(width: 260)
            .modifier(CardBackground())
            .animation(.snappy, value: phase)
            .accessibilityElement(children: .combine)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func title(for phase: StatusCardModel.Phase) -> String {
        switch phase {
        case .resolving: "Tumbling out the tracking…"
        case .done(.cleaned): "Link cleaned"
        case .done(.alreadyClean), .done(.noLink): "Ready to share"
        }
    }

    private func subtitle(for phase: StatusCardModel.Phase) -> String? {
        switch phase {
        case .done(.alreadyClean): "No tracking found"
        case .done(.noLink): "No link to clean"
        case .resolving, .done(.cleaned): nil
        }
    }
}

private struct CardBackground: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }
}

#Preview("Resolving") {
    let model = StatusCardModel()
    model.phase = .resolving
    return StatusCardView(model: model)
}

#Preview("Cleaned") {
    let model = StatusCardModel()
    model.phase = .done(.cleaned)
    return StatusCardView(model: model)
}
