import SwiftUI

struct OnboardingBullet: Identifiable {
    let key: String
    let text: String

    var id: String { "\(key)-\(text)" }
}

struct OnboardingPageView<Hero: View, Content: View>: View {
    let pageIndex: Int
    let pageCount: Int
    let eyebrow: String
    let title: String
    let bodyText: String?
    let primaryButtonTitle: String?
    let primaryShowsBolt: Bool
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    let hero: Hero
    let content: Content

    init(
        pageIndex: Int,
        pageCount: Int = 6,
        eyebrow: String,
        title: String,
        bodyText: String? = nil,
        primaryButtonTitle: String? = "Weiter",
        primaryShowsBolt: Bool = false,
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.eyebrow = eyebrow
        self.title = title
        self.bodyText = bodyText
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryShowsBolt = primaryShowsBolt
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
        self.hero = hero()
        self.content = content()
    }

    var body: some View {
        ZStack {
            BoltBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 12) {
                            BoltEyebrow(eyebrow, color: .boltTealDeep)

                            Text(title)
                                .font(.system(size: 44, weight: .heavy))
                                .lineSpacing(0)
                                .foregroundStyle(Color.boltInk)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.78)
                                .fixedSize(horizontal: false, vertical: true)

                            if let bodyText {
                                Text(bodyText)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(Color.boltInkSoft)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        content

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }

                footer
            }
            .padding(.top, 12)
        }
    }

    private var header: some View {
        HStack {
            BoltSLockup(size: 28)
                .accessibilityLabel("Stromer")

            Spacer()

            Text(pageCounter)
                .font(.boltMono(10))
                .tracking(2)
                .foregroundStyle(Color.boltInkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            progressBar

            if let primaryButtonTitle, let primaryAction {
                BoltPrimary(
                    primaryButtonTitle,
                    showsBolt: primaryShowsBolt,
                    action: primaryAction
                )
            }

            if let secondaryButtonTitle, let secondaryAction {
                BoltSecondary(secondaryButtonTitle, action: secondaryAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 24)
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { index in
                Rectangle()
                    .fill(index <= pageIndex ? Color.boltTeal : Color.boltHair)
                    .frame(height: 3)
            }
        }
        .accessibilityLabel("Onboarding Fortschritt \(pageIndex + 1) von \(pageCount)")
    }

    private var pageCounter: String {
        let current = String(format: "%02d", pageIndex + 1)
        let total = String(format: "%02d", pageCount)
        return "\(current) / \(total)"
    }
}

struct OnboardingBulletList: View {
    let bullets: [OnboardingBullet]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(bullets.enumerated()), id: \.element.id) { index, bullet in
                HStack(alignment: .top, spacing: 12) {
                    Text(bullet.key)
                        .font(.boltMono(12))
                        .fontWeight(.heavy)
                        .tracking(0.8)
                        .foregroundStyle(Color.boltTeal)
                        .frame(width: 36, alignment: .leading)

                    Text(bullet.text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.boltInk)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                if index < bullets.count - 1 {
                    Rectangle()
                        .fill(Color.boltHair2)
                        .frame(height: 1)
                        .padding(.leading, 62)
                }
            }
        }
        .background(Color.boltPaper)
        .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
    }
}

struct OnboardingWelcomeHero: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.boltTeal)

            Text("S")
                .font(.system(size: 124, weight: .heavy))
                .foregroundStyle(Color.boltCream)

            BoltGlyph(
                size: 62,
                fillColor: .boltYellow,
                strokeColor: .boltTeal,
                strokeWidth: 2
            )
            .offset(x: 24, y: -2)
        }
        .frame(width: 164, height: 164)
    }
}

struct OnboardingBandsHero: View {
    private let rows: [(String, String, String)] = [
        ("BLE", "-62 dBm", "antenna.radiowaves.left.and.right"),
        ("LIVE", "12.74 V · 86%", "bolt.fill"),
        ("LOKAL", "iPhone", "iphone")
    ]

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 8) {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.2)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.boltTeal)
                            .frame(width: 24)

                        Text(row.0)
                            .font(.boltMono(12))
                            .fontWeight(.heavy)
                            .foregroundStyle(Color.boltInk)

                        Spacer()

                        Text(row.1)
                            .font(.boltMono(11))
                            .foregroundStyle(Color.boltInkSoft)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.boltPaper)
                    .overlay(Rectangle().stroke(Color.boltHair, lineWidth: 1))
                }
            }

            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color.boltYellow)
                    .frame(width: 3, height: 40)
                BoltGlyph(size: 18)
                Rectangle()
                    .fill(Color.boltYellow)
                    .frame(width: 3, height: 40)
            }
            .offset(x: 10)
        }
        .frame(width: 252, height: 144)
    }
}

struct OnboardingAntennaHero: View {
    var body: some View {
        ZStack {
            ForEach([110, 82, 54], id: \.self) { size in
                Circle()
                    .stroke(Color.boltHair, lineWidth: 2)
                    .frame(width: CGFloat(size), height: CGFloat(size))
            }

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(Color.boltTeal)

            BoltGlyph(size: 28)
                .offset(x: 38, y: -34)
        }
        .frame(width: 140, height: 140)
    }
}

struct OnboardingShieldHero: View {
    var body: some View {
        ZStack {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(Color.boltTeal)

            Text("KEYS")
                .font(.boltMono(10))
                .fontWeight(.heavy)
                .tracking(1.2)
                .foregroundStyle(Color.boltCream)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.boltInk.opacity(0.82))
                .offset(y: 22)

            BoltGlyph(
                size: 30,
                fillColor: .boltYellow,
                strokeColor: .boltTeal
            )
            .offset(x: 34, y: -35)
        }
        .frame(width: 140, height: 140)
    }
}

struct OnboardingKeyHero: View {
    var body: some View {
        ZStack {
            Image(systemName: "key.fill")
                .font(.system(size: 82, weight: .bold))
                .foregroundStyle(Color.boltTeal)

            BoltGlyph(size: 34)
                .offset(x: 54, y: -30)
        }
        .frame(width: 140, height: 120)
    }
}

struct OnboardingAddHero: View {
    var body: some View {
        ZStack {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 100, weight: .bold))
                .foregroundStyle(Color.boltTeal)

            BoltGlyph(size: 34)
                .offset(x: 42, y: -42)
        }
        .frame(width: 140, height: 132)
    }
}
