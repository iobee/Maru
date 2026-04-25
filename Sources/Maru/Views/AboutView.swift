import AppKit
import SwiftUI

enum AboutCardLayout {
    static let pageHorizontalPadding: CGFloat = 64
    static let pageTopPadding: CGFloat = 56
    static let titleToCardSpacing: CGFloat = 44
    static let contentMaxWidth: CGFloat = 720
    static let cardMaxWidth: CGFloat = 700
    static let cardMinHeight: CGFloat = 420
    static let cardPadding: CGFloat = 52
    static let cardCornerRadius: CGFloat = 32
    static let iconSize: CGFloat = 92
    static let titleFontSize: CGFloat = 50
    static let sloganFontSize: CGFloat = 24
    static let descriptionFontSize: CGFloat = 15
    static let contentColumnMaxWidth: CGFloat = 540
    static let centerGuideLength: CGFloat = 220
    static let shadowRadius: CGFloat = 60
    static let shadowYOffset: CGFloat = 24
}

struct AboutView: View {
    private let state = AboutViewState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AboutCardLayout.titleToCardSpacing) {
            pageHeader

            aboutCard
                .frame(maxWidth: AboutCardLayout.cardMaxWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: AboutCardLayout.contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, AboutCardLayout.pageHorizontalPadding)
        .padding(.trailing, AboutCardLayout.pageHorizontalPadding)
        .padding(.top, AboutCardLayout.pageTopPadding)
        .padding(.bottom, 30)
        .background(pageBackground.ignoresSafeArea(.container, edges: .top))
    }
}

private extension AboutView {
    var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关于")
                .font(.system(size: 34, weight: .semibold))

            Text("Maru 的产品名片。")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(nsImage: AppIconProvider.loadAppIcon(size: AboutCardLayout.iconSize))
                .resizable()
                .interpolation(.high)
                .frame(width: AboutCardLayout.iconSize, height: AboutCardLayout.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10), radius: 12, x: 0, y: 7)

            VStack(alignment: .leading, spacing: 10) {
                Text(state.appName)
                    .font(.system(size: AboutCardLayout.titleFontSize, weight: .bold))
                    .foregroundStyle(.primary)

                Text(state.signatureText)
                    .font(.system(size: AboutCardLayout.sloganFontSize, weight: .medium))
                    .foregroundStyle(sloganForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 34)

            Text(state.productDescriptionText)
                .font(.system(size: AboutCardLayout.descriptionFontSize, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: AboutCardLayout.contentColumnMaxWidth, alignment: .leading)
                .padding(.top, 38)

            Spacer(minLength: 48)

            HStack(alignment: .center, spacing: 16) {
                Text(state.releaseLineText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 24)

                GitHubCapsuleLink(title: state.githubDisplayText, destination: state.githubURL)
            }
            .frame(maxWidth: AboutCardLayout.contentColumnMaxWidth, alignment: .leading)
        }
        .padding(AboutCardLayout.cardPadding)
        .frame(maxWidth: .infinity, minHeight: AboutCardLayout.cardMinHeight, alignment: .topLeading)
        .background(cardBackground)
    }

    var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.980, green: 0.984, blue: 0.992),
                    Color(red: 0.965, green: 0.969, blue: 0.976)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.345, green: 0.518, blue: 1.0).opacity(0.08),
                    Color(red: 0.345, green: 0.518, blue: 1.0).opacity(0.02),
                    Color.clear
                ],
                center: UnitPoint(x: 0.58, y: 0.35),
                startRadius: 0,
                endRadius: 430
            )
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: AboutCardLayout.cardCornerRadius, style: .continuous)
            .fill(cardFillColor)
            .overlay(centeringAtmosphere)
            .clipShape(RoundedRectangle(cornerRadius: AboutCardLayout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AboutCardLayout.cardCornerRadius, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: 1)
            )
            .shadow(
                color: Color(red: 0.059, green: 0.090, blue: 0.165).opacity(colorScheme == .dark ? 0.22 : 0.06),
                radius: AboutCardLayout.shadowRadius,
                x: 0,
                y: AboutCardLayout.shadowYOffset
            )
            .shadow(
                color: Color(red: 0.059, green: 0.090, blue: 0.165).opacity(colorScheme == .dark ? 0.16 : 0.04),
                radius: 16,
                x: 0,
                y: 4
            )
    }

    var cardFillColor: Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor).opacity(0.72)
            : Color.white.opacity(0.72)
    }

    var cardBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    var sloganForeground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.231, green: 0.510, blue: 0.965),
                Color(red: 0.365, green: 0.486, blue: 0.886)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var centeringAtmosphere: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                Rectangle()
                    .fill(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.010))
                    .frame(width: 1)
                    .frame(height: AboutCardLayout.centerGuideLength)
                    .position(x: width / 2, y: height / 2)

                Rectangle()
                    .fill(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.009))
                    .frame(height: 1)
                    .frame(width: AboutCardLayout.centerGuideLength)
                    .position(x: width / 2, y: height / 2)

                Circle()
                    .fill(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.018))
                    .frame(width: 8, height: 8)
                    .position(x: width / 2, y: height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct GitHubCapsuleLink: View {
    let title: String
    let destination: URL

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Link(destination: destination) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.145, green: 0.388, blue: 0.922).opacity(colorScheme == .dark ? 0.92 : 0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(buttonBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var buttonBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.black.opacity(isHovered ? 0.07 : 0.04))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.46), lineWidth: 0.8)
            )
    }
}
