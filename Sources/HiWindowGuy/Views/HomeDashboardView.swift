import SwiftUI

struct HomeDashboardView: View {
    @Binding var isWindowManagementEnabled: Bool
    @EnvironmentObject private var appConfig: AppConfig

    private var state: HomeDashboardState {
        HomeDashboardState(
            appRules: appConfig.appRules,
            isEnabled: isWindowManagementEnabled,
            windowScaleFactor: appConfig.windowScaleFactor
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dashboardHeader
                heroControlCard
                scaleControlCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }
}

private extension HomeDashboardView {
    var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(state.headerSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var heroControlCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    statusBadge

                    Text(state.heroTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(state.heroDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Toggle("", isOn: $isWindowManagementEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(1.15)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(state.heroToggleTitle)
                    .font(.headline)

                Text(state.heroToggleSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
    }

    var scaleControlCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.scaleTitle)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(state.scaleDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Text(state.scaleText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }

            Slider(value: $appConfig.windowScaleFactor, in: 0.80...1.00, step: 0.01)
                .tint(.blue)

            HStack {
                Text("更紧凑")
                Spacer()
                Text("更宽松")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(state.scaleFootnote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scaleCardBackground)
    }

    var statusBadge: some View {
        Label(state.statusTitle, systemImage: isWindowManagementEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.10))
            )
    }

    var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
            )
    }

    var scaleCardBackground: some View {
        standardCardBackground(cornerRadius: 22)
    }

    func standardCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }
}
