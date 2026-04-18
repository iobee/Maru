import AppKit
import SwiftUI

struct AboutView: View {
    private let state = AboutViewState()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeader

            Spacer(minLength: 0)

            aboutCard
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(pageBackground.ignoresSafeArea(.container, edges: .top))
    }
}

private extension AboutView {
    var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关于")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("HiWindowGuy 的产品名片。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    var aboutCard: some View {
        HStack(alignment: .center, spacing: 30) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 18) {
                    Image(nsImage: AppIconProvider.makeAppIcon(size: 92))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(state.releaseLineText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)

                        Text(state.updateStatusTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 42)

                VStack(alignment: .leading, spacing: 14) {
                    Text(state.signatureText)
                        .font(.system(size: 44, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.93))

                    Text(state.appName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(.primary)

                    Text(state.metaLineText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 210, height: 210)
                    .blur(radius: 42)

                AboutAccentMark()
                    .frame(width: 198, height: 198)
            }
            .frame(width: 240, height: 240)
        }
        .padding(36)
        .frame(maxWidth: 860, minHeight: 360)
        .background(cardBackground)
    }

    var pageBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.015),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 130)
                .offset(x: 320, y: -220)
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .windowBackgroundColor).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.blue.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.22),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.16),
                radius: 24,
                x: 0,
                y: 18
            )
    }
}

private struct AboutAccentMark: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                Path { path in
                    let rect = CGRect(
                        x: size * 0.18,
                        y: size * 0.38,
                        width: size * 0.28,
                        height: size * 0.28
                    )
                    path.addRoundedRect(
                        in: rect,
                        cornerSize: CGSize(width: size * 0.09, height: size * 0.09)
                    )
                }
                .stroke(
                    Color.white.opacity(0.84),
                    style: StrokeStyle(
                        lineWidth: size * 0.09,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: size * 0.40, y: size * 0.52))
                    path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.27))
                    path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.42))
                }
                .stroke(
                    Color.white.opacity(0.84),
                    style: StrokeStyle(
                        lineWidth: size * 0.09,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: size * 0.66, y: size * 0.27))
                    path.addLine(to: CGPoint(x: size * 0.77, y: size * 0.17))
                }
                .stroke(
                    Color.blue.opacity(0.95),
                    style: StrokeStyle(
                        lineWidth: size * 0.035,
                        lineCap: .round
                    )
                )
            }
            .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 8)
        }
    }
}
