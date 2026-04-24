import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))

            Text(title)
                .font(.headline)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: tint.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}
