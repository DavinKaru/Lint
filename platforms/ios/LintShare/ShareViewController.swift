import LintCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.lint.share", category: "Lint")

/// Share extension entry point: receives a share, cleans the URL inside it, copies the cleaned
/// result to the clipboard, and briefly confirms that with a small card before closing itself.
///
/// Unlike Android, this doesn't re-share through a second share sheet: iOS always presents a
/// share extension as a sheet of its own, so re-sharing from inside it leaves an empty sheet
/// behind the new one (and lists Lint in its own share sheet). Copying is the usual iOS pattern
/// for link tools instead.
final class ShareViewController: UIViewController {

    /// What the share contained. A bare URL is copied as a URL (so apps that paste it get a proper
    /// link); text is copied as text, with only its first URL cleaned.
    private enum SharedContent {
        case url(URL)
        case text(String)

        var text: String {
            switch self {
            case .url(let url): url.absoluteString
            case .text(let text): text
            }
        }
    }

    /// How long the "copied" confirmation stays up before the extension closes itself.
    private static let confirmationDuration: Duration = .seconds(1.2)

    private let cardModel = StatusCardModel()
    private var hasStarted = false
    private var hasFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let card = UIHostingController(rootView: StatusCardView(model: cardModel))
        card.view.backgroundColor = .clear
        card.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(card)
        view.addSubview(card.view)
        NSLayoutConstraint.activate([
            card.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        card.didMove(toParent: self)

        // Tapping anywhere skips the rest of the confirmation.
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissEarly)))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let content = await loadSharedContent() else {
            logger.debug("no URL or text in share, finishing")
            finish()
            return
        }

        let sharedText = content.text
        let cleanedText: String

        if let urlMatch = UrlCleaner.findFirstUrl(in: sharedText), ShortLinkResolver.isKnownShortLink(urlMatch.url) {
            logger.debug("known short link detected, resolving: \(urlMatch.url)")
            withAnimation(.snappy) { cardModel.phase = .resolving }
            // Short links carry no tracking params directly -- they only appear after the
            // redirect to the full URL, so resolve first. Every other link below completes with
            // no network access.
            let resolvedUrl = await ShortLinkResolver.resolveOverNetwork(urlMatch.url)
            if resolvedUrl == urlMatch.url {
                logger.warning("resolution failed or timed out, falling back to original short link")
            } else {
                logger.debug("resolved to: \(resolvedUrl)")
            }
            let cleanedUrl = UrlCleaner.cleanUrl(resolvedUrl) ?? resolvedUrl
            cleanedText = sharedText.replacingCharacters(in: urlMatch.range, with: cleanedUrl)
            logger.debug("cleaned after resolving: \(cleanedText)")
        } else {
            cleanedText = UrlCleaner.cleanFirstUrl(in: sharedText)
            logger.debug("cleaned offline: \(cleanedText)")
        }

        switch content {
        case .url:
            copy(url: URL(string: cleanedText), text: cleanedText)
        case .text:
            copy(url: nil, text: cleanedText)
        }

        let didClean = cleanedText != sharedText
        withAnimation(.snappy) { cardModel.phase = .copied(didClean: didClean) }
        UIAccessibility.post(notification: .announcement, argument: didClean ? "Link cleaned and copied" : "Link copied")

        try? await Task.sleep(for: Self.confirmationDuration)
        finish()
    }

    // MARK: - Reading the share

    /// Returns the first web URL in the share, falling back to the first piece of plain text.
    private func loadSharedContent() async -> SharedContent? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadObject(URL.self, from: provider), ["http", "https"].contains(url.scheme?.lowercased()) {
                return .url(url)
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = await loadObject(String.self, from: provider), !text.isEmpty {
                return .text(text)
            }
        }
        return nil
    }

    private func loadObject<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
    where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { object, _ in
                continuation.resume(returning: object)
            }
        }
    }

    // MARK: - Output

    /// Copies the cleaned result. A URL is copied as both a URL and plain text, so it pastes as a
    /// link where that's supported and as text everywhere else.
    private func copy(url: URL?, text: String) {
        if let url {
            UIPasteboard.general.setItems([[UTType.url.identifier: url, UTType.plainText.identifier: text]])
        } else {
            UIPasteboard.general.string = text
        }
    }

    @objc private func dismissEarly() {
        // Only once the result is on the clipboard -- never cut resolution short.
        if case .copied = cardModel.phase { finish() }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}
