import LintCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.lint.share", category: "Lint")

/// Share extension entry point: receives a share, cleans the URL inside it, and re-shares the
/// cleaned link through a new share sheet -- the same flow as Android. A small status card shows
/// a spinner while a short link is being resolved, since that involves a short network wait.
///
/// iOS always presents a share extension inside a system sheet, so the card stays up (as "Link
/// cleaned") behind the re-opened share sheet rather than leaving that sheet empty.
///
/// Unlike Android, Lint still lists itself in the share sheet it re-opens: iOS has no way to
/// exclude a third-party extension from `UIActivityViewController`, and marking the shared item
/// so Lint's activation rule refuses it also made some other apps (e.g. Reminders) refuse it.
final class ShareViewController: UIViewController {

    /// What the share contained. A bare URL is re-shared as a URL (so the next app gets a proper
    /// link preview); text is re-shared as text, with only its first URL cleaned.
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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The share sheet can only be presented once this view is on screen.
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

        withAnimation(.snappy) {
            cardModel.phase = .cleaned(didClean: cleanedText != sharedText)
        }

        switch content {
        case .url:
            reshare(url: URL(string: cleanedText), text: cleanedText)
        case .text:
            reshare(url: nil, text: cleanedText)
        }
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

    // MARK: - Re-sharing

    private func reshare(url: URL?, text: String) {
        let item: Any = url ?? text
        let activityController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        activityController.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.finish()
        }
        // iPad presents the share sheet as a popover, which needs an anchor.
        activityController.popoverPresentationController?.sourceView = view
        activityController.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0
        )
        activityController.popoverPresentationController?.permittedArrowDirections = []
        present(activityController, animated: true)
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}

@MainActor
private func loadObject<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
where T._ObjectiveCType: NSItemProviderReading {
    await withCheckedContinuation { continuation in
        _ = provider.loadObject(ofClass: type) { object, _ in
            continuation.resume(returning: object)
        }
    }
}
