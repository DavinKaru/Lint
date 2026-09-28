import SwiftUI

/// Lint lives in the share sheet; iOS just requires an app to ship the share extension in. This
/// screen only explains how to use it -- there are no accounts and no settings.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Lint strips tracking parameters like utm_source and fbclid from links when you share them. Everything happens on your device.")
                }

                Section("How to use") {
                    Step(number: 1, text: "Tap Share on a link in any app.")
                    Step(number: 2, text: "Choose Lint from the share sheet.")
                    Step(number: 3, text: "The share sheet reopens with the cleaned link, ready to send.")
                }

                Section {
                    Text("Don't see Lint? Scroll to the end of the row of apps in the share sheet, tap More, and add it.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Lint")
        }
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    ContentView()
}
