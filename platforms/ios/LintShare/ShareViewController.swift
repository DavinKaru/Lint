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

    /// What the share contained. A URL is re-shared as a URL (so the next app gets a proper link
    /// preview), along with any separate message that came with it; text is re-shared as text,
    /// with only its first URL cleaned -- the same as Android's EXTRA_TEXT.
    private enum SharedContent {
        case url(URL, message: String?)
        case text(String)

        var text: String {
            switch self {
            case .url(let url, _): url.absoluteString
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

        let outcome: StatusCardModel.Outcome =
            if UrlCleaner.findFirstUrl(in: sharedText) == nil { .noLink }
            else if cleanedText != sharedText { .cleaned }
            else { .alreadyClean }
        withAnimation(.snappy) { cardModel.phase = .done(outcome) }

        switch content {
        case .url(_, let message):
            let cleanedUrl: Any = URL(string: cleanedText) ?? cleanedText
            reshare(message.map { [$0, cleanedUrl] } ?? [cleanedUrl])
        case .text:
            reshare([cleanedText])
        }
    }

    // MARK: - Reading the share

    /// Reads the share. Text that contains a link wins (it's what Android's EXTRA_TEXT carries,
    /// and cleaning the link in place keeps the message around it); otherwise the first web URL,
    /// keeping any separate message; otherwise plain text as-is.
    private func loadSharedContent() async -> SharedContent? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        var url: URL?
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let candidate = await loadObject(URL.self, from: provider),
               ["http", "https"].contains(candidate.scheme?.lowercased()) {
                url = candidate
                break
            }
        }

        var text: String?
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let candidate = await loadObject(String.self, from: provider), !isBlank(candidate) {
                text = candidate
                break
            }
        }
        // Some apps put their message in the item's content text rather than an attachment.
        if text == nil {
            text = items.lazy.compactMap { $0.attributedContentText?.string }.first { !self.isBlank($0) }
        }

        // Many apps (Safari included) send the link's own URL string as the text too; that's not
        // a message, so it shouldn't turn a URL share into a text share.
        if let candidate = text, let url, isJustUrl(candidate, url) { text = nil }

        if let text, UrlCleaner.findFirstUrl(in: text) != nil { return .text(text) }
        if let url { return .url(url, message: text) }
        if let text { return .text(text) }
        return nil
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isJustUrl(_ text: String, _ url: URL) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == url.absoluteString || URL(string: trimmed) == url
    }

    // MARK: - Re-sharing

    private func reshare(_ items: [Any]) {
        // If the host app has already dismissed Lint (e.g. mid-resolve), there's nothing to present
        // on; finish rather than leave the request open until iOS kills the extension.
        guard view.window != nil, presentedViewController == nil else {
            logger.warning("can't present share sheet, finishing")
            finish()
            return
        }

        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
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
