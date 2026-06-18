import SwiftUI

/// A small prompt asking the user to star the project on GitHub. Shown once the
/// user has received enough notifications. Two choices: star now or maybe later.
struct StarPromptView: View {
    let onStar: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Enjoying ClaudeCodeNotify?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("A GitHub star takes a second and helps the project a lot.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button("⭐ Star on GitHub", action: onStar)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Maybe later", action: onLater)
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 380)
    }
}
