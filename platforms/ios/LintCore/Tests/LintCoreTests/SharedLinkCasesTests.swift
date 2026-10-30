import Foundation
import Testing
@testable import LintCore

/// Runs every case in `shared/tests/link-cases.json`, the test set shared with Android, so both
/// platforms are checked against the same real shared links.
struct SharedLinkCasesTests {

    struct CleanCase: Decodable, Sendable, CustomTestStringConvertible {
        let source: String
        let category: String
        let input: String
        let expected: String
        var testDescription: String { "\(source): \(input.prefix(80))" }
    }

    struct ShortLinkCase: Decodable, Sendable, CustomTestStringConvertible {
        let source: String
        let url: String
        let known: Bool
        var testDescription: String { "\(source): \(url)" }
    }

    struct Cases: Decodable, Sendable {
        let clean: [CleanCase]
        let shortLinks: [ShortLinkCase]
    }

    /// Found relative to this file, so it works from any checkout (repo root is five levels up).
    static let cases: Cases = {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LintCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LintCore
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // platforms
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("shared/tests/link-cases.json")
        do {
            return try JSONDecoder().decode(Cases.self, from: Data(contentsOf: file))
        } catch {
            fatalError("Couldn't load shared link cases from \(file.path): \(error)")
        }
    }()

    @Test func sharedCasesAreNotEmpty() {
        #expect(!Self.cases.clean.isEmpty)
        #expect(!Self.cases.shortLinks.isEmpty)
    }

    @Test(arguments: cases.clean)
    func cleansSharedCase(_ testCase: CleanCase) {
        #expect(UrlCleaner.cleanFirstUrl(in: testCase.input) == testCase.expected)
    }

    @Test(arguments: cases.shortLinks)
    func matchesSharedShortLinkCase(_ testCase: ShortLinkCase) {
        #expect(ShortLinkResolver.isKnownShortLink(testCase.url) == testCase.known)
    }
}
