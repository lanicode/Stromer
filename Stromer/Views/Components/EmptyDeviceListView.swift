import SwiftUI

struct EmptyDeviceListView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BoltGlyph(
                size: 60,
                fillColor: .boltYellow,
                strokeColor: .boltTeal,
                strokeWidth: 2
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            BoltEyebrow("Noch nichts", color: .boltTealDeep)

            Text("Kein Gerät\nverbunden.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color.boltInk)
                .lineSpacing(0)

            Text("Füge dein erstes Victron-Gerät hinzu.")
                .font(.system(size: 15))
                .foregroundStyle(Color.boltInkSoft)

            BoltPrimary("Gerät hinzufügen", showsBolt: true, action: addAction)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
        .padding(.horizontal, 18)
    }
}
